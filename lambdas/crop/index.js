const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

// Inicializamos el cliente S3
const s3 = new S3Client({}); 
const BUCKET_NAME = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX || "processed/";

exports.handler = async (event) => {
  const failedMessageIds = [];

  for (const record of event.Records) {
    try {
      const messageBody = JSON.parse(record.body);
      if (!messageBody.Records) continue; // Si no es un evento de S3, salir rápido

      for (const s3Record of messageBody.Records) {
        const bucket = s3Record.s3.bucket.name;
        // Prevenir errores por nombres de archivos con espacios codificados
        const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, " "));

        console.log(`Procesando imagen: ${key}`);

        // 1. Descargamos el original
        const s3Object = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
        const imageBuffer = await streamToBuffer(s3Object.Body);

        // 2. Aplicamos Sharp (40x40 Circular)
        const width = 40, height = 40;
        const circleSvg = Buffer.from(
          `<svg><circle cx="${width/2}" cy="${height/2}" r="${width/2}" /></svg>`
        );

        const processedBuffer = await sharp(imageBuffer)
          .resize(width, height, { fit: "cover" })
          .composite([{ input: circleSvg, blend: "dest-in" }])
          .png({ compressionLevel: 9 })
          .toBuffer();

        // 3. Subimos el procesado a la carpeta destino
        const originalFileName = key.split("/").pop();
        const newKey = `${PROCESSED_PREFIX}${originalFileName.split('.')[0]}_circular.png`;

        await s3.send(new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: newKey,
          Body: processedBuffer,
          ContentType: "image/png",
        }));
      }
    } catch (error) {
      console.error(`Error en SQS ID: ${record.messageId}`, error);
      failedMessageIds.push(record.messageId); 
    }
  }

  // Devolvemos a SQS solo los IDs que fallaron, el resto se borran correctamente
  return { batchItemFailures: failedMessageIds.map(id => ({ itemIdentifier: id })) };
};

const streamToBuffer = (stream) => new Promise((resolve, reject) => {
  const chunks = [];
  stream.on("data", chunk => chunks.push(chunk));
  stream.on("error", reject);
  stream.on("end", () => resolve(Buffer.concat(chunks)));
});