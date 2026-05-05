const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { v4: uuidv4 } = require("uuid");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET = process.env.S3_BUCKET;
const PREFIX = process.env.UPLOAD_PREFIX || "uploads/";

exports.handler = async (event) => {
    try {
        const body = JSON.parse(event.body);
        const imageBuffer = Buffer.from(body.image_base64, "base64");
        const fileName = `${PREFIX}${uuidv4()}-${body.filename}`;

        await s3.send(new PutObjectCommand({
            Bucket: BUCKET,
            Key: fileName,
            Body: imageBuffer,
            ContentType: "image/jpeg"
        }));

        return {
            statusCode: 200,
            body: JSON.stringify({ message: "¡Foto subida con éxito!", file: fileName })
        };
    } catch (error) {
        console.error(error);
        return { statusCode: 500, body: JSON.stringify({ error: "Upload fallido" }) };
    }
};