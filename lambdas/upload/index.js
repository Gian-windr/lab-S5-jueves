const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const busboy = require("busboy");
const { v4: uuidv4 } = require("uuid");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET_NAME = process.env.S3_BUCKET;
const UPLOAD_PREFIX = process.env.UPLOAD_PREFIX;

const parseMultipart = (event) => {
  return new Promise((resolve, reject) => {
    const bb = busboy({
      headers: {
        "content-type":
          event.headers["Content-Type"] || event.headers["content-type"],
      },
    });

    let fileContent, fileName, contentType;

    bb.on("file", (fieldname, file, info) => {
      const { filename, encoding, mimeType } = info;
      console.log(
        `File [${fieldname}]: filename: %j, encoding: %j, mimeType: %j`,
        filename,
        encoding,
        mimeType
      );

      const chunks = [];
      file.on("data", (chunk) => {
        chunks.push(chunk);
      });
      file.on("end", () => {
        fileContent = Buffer.concat(chunks);
        fileName = filename;
        contentType = mimeType;
      });
    });

    bb.on("finish", () => {
      if (!fileContent) {
        return reject(new Error("No file uploaded."));
      }
      resolve({ fileContent, fileName, contentType });
    });

    bb.on("error", (err) => {
      reject(err);
    });

    bb.end(Buffer.from(event.body, event.isBase64Encoded ? "base64" : "binary"));
  });
};

exports.handler = async (event) => {
  try {
    console.log("Iniciando proceso de carga de archivo...");

    let fileContent, originalFileName, contentType;
    const contentTypeHeader = event.headers["Content-Type"] || event.headers["content-type"];

    if (contentTypeHeader && contentTypeHeader.startsWith("multipart/form-data")) {
      console.log("Procesando multipart/form-data");
      const result = await parseMultipart(event);
      fileContent = result.fileContent;
      originalFileName = result.fileName;
      contentType = result.contentType;
    } else if (event.isBase64Encoded) {
        console.log("Manejando payload JSON codificado en base64");
        const body = JSON.parse(Buffer.from(event.body, 'base64').toString('utf8'));
        if (!body.image || !body.filename) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: "Falta la imagen o el nombre del archivo en el cuerpo JSON" }),
            };
        }
        fileContent = Buffer.from(body.image, 'base64');
        originalFileName = body.filename;
        // Detección de tipo MIME súper básica a partir de la extensión
        const extension = originalFileName.split('.').pop().toLowerCase();
        const mimeTypes = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'gif': 'image/gif',
            'webp': 'image/webp'
        };
        contentType = mimeTypes[extension] || 'application/octet-stream';
    } else {
       return {
            statusCode: 400,
            body: JSON.stringify({ message: "Tipo de contenido no soportado. Por favor, use multipart/form-data o JSON con imagen en base64." }),
        };
    }

    const fileExtension = originalFileName.split(".").pop();
    const newFileName = `${uuidv4()}.${fileExtension}`;
    const s3Key = `${UPLOAD_PREFIX}${newFileName}`;

    console.log(`Subiendo a S3: bucket=${BUCKET_NAME}, key=${s3Key}`);

    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: s3Key,
      Body: fileContent,
      ContentType: contentType,
    });

    await s3.send(command);

    console.log("Archivo subido exitosamente");

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "¡Archivo subido exitosamente!",
        bucket: BUCKET_NAME,
        key: s3Key,
      }),
    };
  } catch (error) {
    console.error("Error durante la carga del archivo:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Fallo al subir el archivo.",
        error: error.message,
      }),
    };
  }
};