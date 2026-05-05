const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET = process.env.S3_BUCKET;

// Helper para convertir el stream de S3 a Buffer
const streamToBuffer = (stream) => new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks)));
});

exports.handler = async (event) => {
    for (const record of event.Records) {
        const payload = JSON.parse(record.body);
        if (!payload.Records) continue;

        for (const s3Event of payload.Records) {
            const originalKey = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));
            
            // 1. Descargar imagen original
            const getRes = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: originalKey }));
            const imageBuffer = await streamToBuffer(getRes.Body);

            // 2. Recortar circularmente 40x40 (Requisito del diagrama)
            const roundedCorners = Buffer.from(
                '<svg><circle cx="20" cy="20" r="20" /></svg>'
            );

            const processedBuffer = await sharp(imageBuffer)
                .resize(40, 40)
                .composite([{ input: roundedCorners, blend: 'dest-in' }])
                .png()
                .toBuffer();

            // 3. Subir imagen procesada
            const newKey = originalKey.replace("uploads/", "processed/").replace(/\.[^/.]+$/, "_circular.png");
            
            await s3.send(new PutObjectCommand({
                Bucket: BUCKET,
                Key: newKey,
                Body: processedBuffer,
                ContentType: "image/png"
            }));
            console.log(`✅ Avatar procesado: ${newKey}`);
        }
    }
};