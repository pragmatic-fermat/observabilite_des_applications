// tracing.mjs
import { NodeSDK } from "@opentelemetry/sdk-node";
import { ConsoleSpanExporter } from "@opentelemetry/sdk-trace-base";
import { Resource } from "@opentelemetry/resources";import { SemanticResourceAttributes } from "@opentelemetry/semantic-conventions";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";

const resource = new Resource({  [SemanticResourceAttributes.SERVICE_NAME]: "messenger",});

const sdk = new NodeSDK({
	resource,
  traceExporter: new OTLPTraceExporter({ headers: {} }),
  instrumentations: [getNodeAutoInstrumentations()],
  spanLimits: {
    attributeCountLimit: 64,
    attributeValueLengthLimit: 512,
    eventCountLimit: 128,
    eventAttributeCountLimit: 32,
  },
});

await sdk.start();
