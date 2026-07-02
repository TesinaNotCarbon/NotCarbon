import {
  Runner,
  consensusIdenticalAggregation,
  cre,
  decodeJson,
  json,
  ok,
  prepareReportRequest,
  type HTTPSendRequester,
  type HTTPPayload,
  type Runtime,
} from "@chainlink/cre-sdk";
import { encodeAbiParameters, isAddress, isHex, type Address, type Hex } from "viem";

type Config = {
  httpPublicKey: string;
  validationApiBaseUrl: string;
  receiverAddress: string;
  chainSelector: string;
  gasLimit: string;
};

type ValidationTriggerPayload = {
  request_id: Hex;
  project_address: Address;
  cell_id: string;
};

type ValidationApiResponse = {
  overlap: boolean;
  inconclusive: boolean;
  matched_cell_ids?: string[];
  checked_count?: number;
  trace_id?: string;
  reason?: string | null;
};

type ValidationResult = {
  overlap: boolean;
  inconclusive: boolean;
  checkedCount: number;
  traceId: string;
  reason: string;
};

const textEncoder = new TextEncoder();

function parseTriggerPayload(payload: HTTPPayload): ValidationTriggerPayload {
  const decoded = decodeJson(payload.input) as Partial<ValidationTriggerPayload>;

  if (!decoded.request_id || !isHex(decoded.request_id, { strict: true }) || decoded.request_id.length !== 66) {
    throw new Error("Invalid request_id");
  }
  if (!decoded.project_address || !isAddress(decoded.project_address)) {
    throw new Error("Invalid project_address");
  }
  if (!decoded.cell_id) {
    throw new Error("Invalid cell_id");
  }

  return {
    request_id: decoded.request_id as Hex,
    project_address: decoded.project_address as Address,
    cell_id: decoded.cell_id,
  };
}

function fetchValidation(sendRequester: HTTPSendRequester, config: Config, cellId: string): ValidationResult {
  const url = `${config.validationApiBaseUrl.replace(/\/$/, "")}/validate-polygon`;
  const response = sendRequester
    .sendRequest({
      url,
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: textEncoder.encode(JSON.stringify({ cell_id: cellId })),
    })
    .result();

  if (!ok(response)) {
    throw new Error(`Validation API failed with status ${response.statusCode}`);
  }

  const data = json(response) as Partial<ValidationApiResponse>;
  if (typeof data.overlap !== "boolean" || typeof data.inconclusive !== "boolean") {
    throw new Error("Validation API response must include boolean overlap and inconclusive fields");
  }

  return {
    overlap: data.overlap,
    inconclusive: data.inconclusive,
    checkedCount: typeof data.checked_count === "number" ? data.checked_count : 0,
    traceId: typeof data.trace_id === "string" ? data.trace_id : "",
    reason: typeof data.reason === "string" ? data.reason : "",
  };
}

function onHttpTrigger(runtime: Runtime<Config>, payload: HTTPPayload): string {
  const request = parseTriggerPayload(payload);
  runtime.log(`Validation requested for ${request.project_address} / ${request.cell_id}`);

  const httpClient = new cre.capabilities.HTTPClient();
  const validation = httpClient
    .sendRequest(runtime, fetchValidation, consensusIdenticalAggregation())(runtime.config, request.cell_id)
    .result();

  runtime.log(
    `Validation API trace=${validation.traceId} checked=${validation.checkedCount} reason=${validation.reason}`,
  );

  const reportPayload = encodeAbiParameters(
    [{ type: "bytes32" }, { type: "bool" }, { type: "bool" }],
    [request.request_id, validation.overlap, validation.inconclusive],
  );
  const report = runtime.report(prepareReportRequest(reportPayload)).result();

  const evmClient = new cre.capabilities.EVMClient(BigInt(runtime.config.chainSelector));
  evmClient
    .writeReport(runtime, {
      receiver: runtime.config.receiverAddress,
      report,
      gasConfig: {
        gasLimit: runtime.config.gasLimit,
      },
    })
    .result();

  return JSON.stringify({
    request_id: request.request_id,
    overlap: validation.overlap,
    inconclusive: validation.inconclusive,
  });
}

function initWorkflow(config: Config) {
  const httpTrigger = new cre.capabilities.HTTPCapability();
  return [
    cre.handler(
      httpTrigger.trigger({
        authorizedKeys:
          config.httpPublicKey === "0x0000000000000000000000000000000000000000"
            ? []
            : [{ type: "KEY_TYPE_ECDSA_EVM", publicKey: config.httpPublicKey }],
      }),
      onHttpTrigger,
    ),
  ];
}

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}

main();
