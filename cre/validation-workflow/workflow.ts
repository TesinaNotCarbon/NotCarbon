import {
  bytesToHex,
  consensusIdenticalAggregation,
  cre,
  encodeCallMsg,
  EVMClient,
  getNetwork,
  hexToBase64,
  json,
  ok,
  prepareReportRequest,
  TxStatus,
  type EVMLog,
  type HTTPSendRequester,
  type Runtime,
} from '@chainlink/cre-sdk'
import {
  decodeEventLog,
  decodeFunctionResult,
  encodeAbiParameters,
  encodeFunctionData,
  isAddress,
  parseAbiParameters,
  zeroAddress,
  type Address,
  type Hex,
} from 'viem'
import { z } from 'zod'

export const configSchema = z.object({
  chainSelectorName: z.string(),
  validationOracleAddress: z.string(),
  validationOracleAddressBase64: z.string(),
  validationRequestedTopic0Base64: z.string(),
  validationApiBaseUrl: z.string().url(),
  gasLimit: z.string(),
})
type Config = z.infer<typeof configSchema>

type ValidationRequestedDecoded = {
  requestId: Hex
  projectAddress: Address
  cellId: string
}

type ValidationRequestState = {
  projectAddress: Address
  cellId: string
  exists: boolean
  pending: boolean
}

type ValidationConsensusResult = {
  overlap: boolean
  inconclusive: boolean
}

type ValidationApiResponse = {
  overlap?: unknown
  inconclusive?: unknown
}

const textEncoder = new TextEncoder()

const validationOracleAbi = [
  {
    type: 'event',
    name: 'ValidationRequested',
    inputs: [
      { name: 'requestId', type: 'bytes32', indexed: true },
      { name: 'projectAddress', type: 'address', indexed: true },
      { name: 'cellId', type: 'string', indexed: false },
    ],
  },
  {
    type: 'function',
    name: 'getValidationRequest',
    stateMutability: 'view',
    inputs: [{ name: 'requestId', type: 'bytes32' }],
    outputs: [
      { name: 'projectAddress', type: 'address' },
      { name: 'cellId', type: 'string' },
      { name: 'exists', type: 'bool' },
      { name: 'pending', type: 'bool' },
    ],
  },
] as const

function getEvmClient(config: Config) {
  const network = getNetwork({
    chainFamily: 'evm',
    chainSelectorName: config.chainSelectorName,
    isTestnet: true,
  })
  if (!network) throw new Error(`Network not found: ${config.chainSelectorName}`)
  return new cre.capabilities.EVMClient(network.chainSelector.selector)
}

function decodeValidationRequested(log: EVMLog): ValidationRequestedDecoded {
  const decoded = decodeEventLog({
    abi: validationOracleAbi,
    eventName: 'ValidationRequested',
    data: bytesToHex(log.data),
    topics: log.topics.map((topic) => bytesToHex(topic)) as [Hex, ...Hex[]],
  })
  return decoded.args as ValidationRequestedDecoded
}

function readValidationRequest(
  runtime: Runtime<Config>,
  evmClient: EVMClient,
  oracleAddress: Address,
  requestId: Hex,
): ValidationRequestState {
  const callData = encodeFunctionData({
    abi: validationOracleAbi,
    functionName: 'getValidationRequest',
    args: [requestId],
  })
  const result = evmClient
    .callContract(runtime, {
      call: encodeCallMsg({ from: zeroAddress, to: oracleAddress, data: callData }),
    })
    .result()

  const [projectAddress, cellId, exists, pending] = decodeFunctionResult({
    abi: validationOracleAbi,
    functionName: 'getValidationRequest',
    data: bytesToHex(result.data),
  }) as [Address, string, boolean, boolean]

  return { projectAddress, cellId, exists, pending }
}

function fetchAreaValidation(
  sendRequester: HTTPSendRequester,
  config: Config,
  cellId: string,
): ValidationConsensusResult {
  const url = `${config.validationApiBaseUrl.replace(/\/$/, '')}/validate-polygon`
  const response = sendRequester
    .sendRequest({
      url,
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: textEncoder.encode(JSON.stringify({ cell_id: cellId })),
    })
    .result()

  if (!ok(response)) {
    throw new Error(`Area validation API failed with status ${response.statusCode}`)
  }

  const data = json(response) as ValidationApiResponse
  if (typeof data.overlap !== 'boolean' || typeof data.inconclusive !== 'boolean') {
    throw new Error('Area validation API response must include boolean overlap and inconclusive fields')
  }

  return { overlap: data.overlap, inconclusive: data.inconclusive }
}

export const onValidationRequested = (runtime: Runtime<Config>, payload: EVMLog): string => {
  const config = runtime.config
  if (!isAddress(config.validationOracleAddress)) {
    throw new Error('Invalid validation oracle address')
  }

  const event = decodeValidationRequested(payload)
  const evmClient = getEvmClient(config)
  const oracleAddress = config.validationOracleAddress as Address
  const state = readValidationRequest(runtime, evmClient, oracleAddress, event.requestId)

  if (!state.exists) throw new Error(`Unknown validation request: ${event.requestId}`)
  if (!state.pending) throw new Error(`Validation request is not pending: ${event.requestId}`)
  if (state.projectAddress.toLowerCase() !== event.projectAddress.toLowerCase()) {
    throw new Error('Validation event project does not match canonical request')
  }
  if (state.cellId.length === 0) throw new Error('Canonical cellId is empty')

  runtime.log(`Validation request ${event.requestId} for ${state.projectAddress}`)

  const httpClient = new cre.capabilities.HTTPClient()
  const validation = httpClient
    .sendRequest(runtime, fetchAreaValidation, consensusIdenticalAggregation())(config, state.cellId)
    .result()

  const reportData = encodeAbiParameters(
    parseAbiParameters('bytes32 requestId, bool overlap, bool inconclusive'),
    [event.requestId, validation.overlap, validation.inconclusive],
  )
  const report = runtime.report(prepareReportRequest(reportData)).result()
  const writeResult = evmClient
    .writeReport(runtime, {
      receiver: oracleAddress,
      report,
      gasConfig: { gasLimit: config.gasLimit },
    })
    .result()

  if (writeResult.txStatus !== TxStatus.SUCCESS) {
    throw new Error(`Validation report TX failed: ${writeResult.errorMessage || writeResult.txStatus}`)
  }

  const txHash = bytesToHex(writeResult.txHash || new Uint8Array(32))
  runtime.log(`Validation report accepted on-chain: ${txHash}`)

  return JSON.stringify({ request_id: event.requestId, tx_hash: txHash })
}

export function initWorkflow(config: Config) {
  const evmClient = getEvmClient(config)
  return [
    cre.handler(
      evmClient.logTrigger({
        addresses: [config.validationOracleAddressBase64 || hexToBase64(config.validationOracleAddress as Hex)],
        topics: [{ values: [config.validationRequestedTopic0Base64] }],
      }),
      onValidationRequested,
    ),
  ]
}
