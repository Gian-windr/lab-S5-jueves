const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET_NAME = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX;

exports.handler = async (event) => {
  const failedMessageIds = [];

  for (const record of event.Records) {
    try {
      const messageBody = JSON.parse(record.body);
      if (!messageBody.Records) {
        console.warn("El mensaje SQS no contiene registros de eventos de S3. Omitiendo.", record.body);
        continue;
      }

      for (const s3Record of messageBody.Records) {
        const bucket = s3Record.s3.bucket.name;
        const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, " "));

        console.log(`Procesando objeto S3: bucket=${bucket}, key=${key}`);

        // 1. Obtener objeto de S3
        const getObjectParams = { Bucket: bucket, Key: key };
        const getObjectCmd = new GetObjectCommand(getObjectParams);
        const s3Object = await s3.send(getObjectCmd);
        const imageBuffer = await streamToBuffer(s3Object.Body);

        // 2. Procesar imagen con Sharp
        const width = 40;
        const height = 40;
        const circleSvg = Buffer.from(
          `<svg><circle cx="${width / 2}" cy="${height / 2}" r="${width / 2}" /></svg>`
        );

        const processedImageBuffer = await sharp(imageBuffer)
          .resize(width, height, { fit: "cover" })
          .composite([{ input: circleSvg, blend: "dest-in" }])
          .png({ compressionLevel: 9, adaptiveFiltering: true, force: true })
          .toBuffer();

        // 3. Subir imagen procesada a S3
        const originalFileName = key.split("/").pop();
        const newFileName = `${originalFileName.split('.')[0]}_circular.png`;
        const newKey = `${PROCESSED_PREFIX}${newFileName}`;

        const putObjectParams = {
          Bucket: BUCKET_NAME,
          Key: newKey,
          Body: processedImageBuffer,
          ContentType: "image/png",
        };
        const putObjectCmd = new PutObjectCommand(putObjectParams);
        await s3.send(putObjectCmd);

        console.log(`Procesado y subido exitosamente a ${newKey}`);
      }
    } catch (error) {
      console.error("Error procesando el registro:", error);
      failedMessageIds.push(record.messageId);
    }
  }

  return {
    batchItemFailures: failedMessageIds.map(id => ({ itemIdentifier: id })),
  };
};

const streamToBuffer = (stream) => {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks)));
  });
};