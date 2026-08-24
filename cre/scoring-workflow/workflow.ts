import {
  bytesToHex,
  ConsensusAggregationByFields,
  cre,
  encodeCallMsg,
  EVMClient,
  getNetwork,
  hexToBase64,
  identical,
  json,
  median,
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
  scoringOracleAddress: z.string(),
  scoringOracleAddressBase64: z.string(),
  scoringRequestedTopic0Base64: z.string(),
  projectManagerAddress: z.string(),
  scoringApiBaseUrl: z.string().url(),
  gasLimit: z.string(),
})
type Config = z.infer<typeof configSchema>

type ScoringRequestedDecoded = {
  requestId: Hex
  projectAddress: Address
}

type ScoringRequestState = {
  projectAddress: Address
  exists: boolean
  pending: boolean
}

type ScoringApiResponse = {
  project_id?: unknown
  cell_id?: unknown
  scoring?: unknown
  fraud_scoring?: unknown
  measurement_date?: unknown
  schema_version?: unknown
}

type ScoringConsensusResult = {
  measurementDate: number
  scoring: number
  fraudScoring: number
}

const scoringOracleAbi = [
  {
    type: 'event',
    name: 'ScoringRequested',
    inputs: [
      { name: 'requestId', type: 'bytes32', indexed: true },
      { name: 'projectAddress', type: 'address', indexed: true },
    ],
  },
  {
    type: 'function',
    name: 'getScoringRequest',
    stateMutability: 'view',
    inputs: [{ name: 'requestId', type: 'bytes32' }],
    outputs: [
      { name: 'projectAddress', type: 'address' },
      { name: 'exists', type: 'bool' },
      { name: 'pending', type: 'bool' },
    ],
  },
] as const

const projectManagerAbi = [
  {
    type: 'function',
    name: 'getProjectCellId',
    stateMutability: 'view',
    inputs: [{ name: 'projectAddress', type: 'address' }],
    outputs: [{ name: 'cellId', type: 'string' }],
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

function decodeScoringRequested(log: EVMLog): ScoringRequestedDecoded {
  const decoded = decodeEventLog({
    abi: scoringOracleAbi,
    eventName: 'ScoringRequested',
    data: bytesToHex(log.data),
    topics: log.topics.map((topic) => bytesToHex(topic)) as [Hex, ...Hex[]],
  })
  return decoded.args as ScoringRequestedDecoded
}

function readScoringRequest(
  runtime: Runtime<Config>,
  evmClient: EVMClient,
  oracleAddress: Address,
  requestId: Hex,
): ScoringRequestState {
  const callData = encodeFunctionData({
    abi: scoringOracleAbi,
    functionName: 'getScoringRequest',
    args: [requestId],
  })
  const result = evmClient
    .callContract(runtime, {
      call: encodeCallMsg({ from: zeroAddress, to: oracleAddress, data: callData }),
    })
    .result()

  const [projectAddress, exists, pending] = decodeFunctionResult({
    abi: scoringOracleAbi,
    functionName: 'getScoringRequest',
    data: bytesToHex(result.data),
  }) as [Address, boolean, boolean]

  return { projectAddress, exists, pending }
}

function readProjectCellId(
  runtime: Runtime<Config>,
  evmClient: EVMClient,
  projectManagerAddress: Address,
  projectAddress: Address,
): string {
  const callData = encodeFunctionData({
    abi: projectManagerAbi,
    functionName: 'getProjectCellId',
    args: [projectAddress],
  })
  const result = evmClient
    .callContract(runtime, {
      call: encodeCallMsg({ from: zeroAddress, to: projectManagerAddress, data: callData }),
    })
    .result()

  return decodeFunctionResult({
    abi: projectManagerAbi,
    functionName: 'getProjectCellId',
    data: bytesToHex(result.data),
  }) as string
}

function fetchScoring(
  sendRequester: HTTPSendRequester,
  config: Config,
  projectAddress: Address,
  cellId: string,
): ScoringConsensusResult {
  const url = `${config.scoringApiBaseUrl.replace(/\/$/, '')}/chainlink/score/${projectAddress}`
  const response = sendRequester.sendRequest({ url, method: 'GET' }).result()

  if (!ok(response)) {
    throw new Error(`Scoring API failed with status ${response.statusCode}`)
  }

  const data = json(response) as ScoringApiResponse
  if (data.schema_version !== 'chainlink-project-scoring-v1') {
    throw new Error('Unexpected scoring schema_version')
  }
  if (typeof data.project_id !== 'string' || data.project_id.toLowerCase() !== projectAddress.toLowerCase()) {
    throw new Error('Scoring API project_id does not match canonical project')
  }
  if (typeof data.cell_id !== 'string' || data.cell_id !== cellId) {
    throw new Error('Scoring API cell_id does not match canonical cell')
  }
  const measurementDate = data.measurement_date
  const scoring = data.scoring
  const fraudScoring = data.fraud_scoring
  if (typeof measurementDate !== 'number' || !Number.isInteger(measurementDate) || measurementDate <= 0) {
    throw new Error('Invalid scoring measurement_date')
  }
  if (typeof scoring !== 'number' || !Number.isInteger(scoring) || scoring < 0 || scoring > 100) {
    throw new Error('Invalid scoring value')
  }
  if (typeof fraudScoring !== 'number' || !Number.isInteger(fraudScoring) || fraudScoring < 0 || fraudScoring > 100) {
    throw new Error('Invalid fraud_scoring value')
  }

  return {
    measurementDate,
    scoring,
    fraudScoring,
  }
}

export const onScoringRequested = (runtime: Runtime<Config>, payload: EVMLog): string => {
  const config = runtime.config
  if (!isAddress(config.scoringOracleAddress)) throw new Error('Invalid scoring oracle address')
  if (!isAddress(config.projectManagerAddress)) throw new Error('Invalid project manager address')

  const event = decodeScoringRequested(payload)
  const evmClient = getEvmClient(config)
  const oracleAddress = config.scoringOracleAddress as Address
  const projectManagerAddress = config.projectManagerAddress as Address
  const state = readScoringRequest(runtime, evmClient, oracleAddress, event.requestId)

  if (!state.exists) throw new Error(`Unknown scoring request: ${event.requestId}`)
  if (!state.pending) throw new Error(`Scoring request is not pending: ${event.requestId}`)
  if (state.projectAddress.toLowerCase() !== event.projectAddress.toLowerCase()) {
    throw new Error('Scoring event project does not match canonical request')
  }

  const cellId = readProjectCellId(runtime, evmClient, projectManagerAddress, state.projectAddress)
  if (cellId.length === 0) throw new Error('Canonical cellId is empty')

  runtime.log(`Scoring request ${event.requestId} for ${state.projectAddress}`)

  const httpClient = new cre.capabilities.HTTPClient()
  const scoring = httpClient
    .sendRequest(
      runtime,
      fetchScoring,
      ConsensusAggregationByFields<ScoringConsensusResult>({
        measurementDate: identical,
        scoring: median,
        fraudScoring: median,
      }),
    )(config, state.projectAddress, cellId)
    .result()

  const reportData = encodeAbiParameters(
    parseAbiParameters('bytes32 requestId, uint256 measurementDate, uint256 scoring, uint256 fraudScoring'),
    [
      event.requestId,
      BigInt(scoring.measurementDate),
      BigInt(Math.round(scoring.scoring)),
      BigInt(Math.round(scoring.fraudScoring)),
    ],
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
    throw new Error(`Scoring report TX failed: ${writeResult.errorMessage || writeResult.txStatus}`)
  }

  const txHash = bytesToHex(writeResult.txHash || new Uint8Array(32))
  runtime.log(`Scoring report accepted on-chain: ${txHash}`)

  return JSON.stringify({ request_id: event.requestId, tx_hash: txHash })
}

export function initWorkflow(config: Config) {
  const evmClient = getEvmClient(config)
  return [
    cre.handler(
      evmClient.logTrigger({
        addresses: [config.scoringOracleAddressBase64 || hexToBase64(config.scoringOracleAddress as Hex)],
        topics: [{ values: [config.scoringRequestedTopic0Base64] }],
      }),
      onScoringRequested,
    ),
  ]
}
