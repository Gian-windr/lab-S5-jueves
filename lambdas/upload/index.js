const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { v4: uuidv4 } = require("uuid");

const s3Client = new S3Client({});
const BUCKET_NAME = process.env.S3_BUCKET;
const UPLOAD_PREFIX = process.env.UPLOAD_PREFIX || "uploads/";

exports.handler = async (event) => {
  console.log("Evento recibido");

  try {
    const { body, isBase64Encoded } = event;
    let imageBuffer;
    let dataBody = body; 

    if (!body) throw new Error("El cuerpo está vacío.");

    try {
      const parsedBody = JSON.parse(body);
      if (parsedBody.body) dataBody = parsedBody.body;
    } catch (e) {
      console.log("No es JSON, asumiendo binario Base64 directo.");
    }

    imageBuffer = isBase64Encoded 
      ? Buffer.from(dataBody, "base64") 
      : Buffer.from(dataBody, "utf-8");
    
    // Convertir keys de headers a minúsculas por seguridad (API GW a veces las varía)
    const headers = Object.keys(event.headers || {}).reduce((acc, key) => {
        acc[key.toLowerCase()] = event.headers[key];
        return acc;
    }, {});
    
    const contentType = headers['content-type'] || 'application/octet-stream';
    const fileExt = contentType.split("/")[1] || "jpg";
    const key = `${UPLOAD_PREFIX}${uuidv4()}.${fileExt}`;

    await s3Client.send(new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: imageBuffer,
      ContentType: contentType,
    }));

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Imagen subida correctamente.", path: key }),
    };
  } catch (error) {
    console.error("Error subiendo el archivo:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
    };
  }
};