# AWS + Lambda: Arquitectura de Procesamiento de Imágenes

Este proyecto implementa una arquitectura serverless para el procesamiento de imágenes en AWS. La infraestructura se gestiona con Terraform para garantizar despliegues consistentes en múltiples entornos.

Alumno: Gianfranco Campos A. - ID: 274878

## Objetivo del Proyecto

Desplegar una solución que permita a los usuarios subir imágenes, las cuales son procesadas automáticamente para generar una versión recortada en formato circular.

## Arquitectura y Entornos

La infraestructura soporta tres entornos de despliegue mediante Workspaces de Terraform:

*   dev (Desarrollo)
*   qa (Calidad)
*   prod (Producción)

## Requisitos Previos

Antes de empezar, necesitas:

*   Terraform (v1.0 o superior)
*   AWS CLI (v2 o superior)
*   Node.js y npm (v18 o superior)
*   Credenciales de AWS configuradas localmente a través de 'aws configure'.

## Instrucciones de Despliegue

**Clonar el repositorio y entrar a la carpeta de infraestructura:**
   ```bash
   git clone https://github.com/Gian-windr/lab-S5-jueves.git
   cd lab-S5-jueves/iac
   ```

## Pasos para el Despliegue (Entorno 'dev')

Sigue estos pasos desde la raíz de tu proyecto.

### 1. Instalar Dependencias de las Lambdas

```
cd lambdas/upload
npm install
cd ../crop
npm install
cd ../..
```

### 2. Inicializar Terraform y Preparar el Entorno

```
cd iac
terraform init
terraform workspace new dev
terraform workspace select dev
```

### 3. Planificar y Aplicar la Infraestructura

```
terraform apply
```
Escribe 'yes' cuando se te pida confirmación.

### 4. Probar la Aplicación

Una vez finalizado, Terraform mostrará la URL del API Gateway en las salidas. Usa esa URL para probar la subida de una imagen.

Ejemplo con curl (reemplaza la URL y la ruta a tu imagen):

```
curl -X POST "URL_DEL_API/upload" -H "Content-Type: image/png" --data-binary "@ruta/a/tu/foto.png"
```

Verifica en la consola de AWS que la imagen original aparece en la carpeta 'uploads/' del bucket S3 y la imagen procesada en la carpeta 'processed/'.

### 5. Destruir la Infraestructura

Para evitar costos, destruye todos los recursos cuando hayas terminado.

```
terraform destroy
```
Escribe 'yes' para confirmar la destrucción.

*Para desplegar en 'qa' o 'prod', simplemente reemplaza 'dev' en los comandos de 'terraform workspace'.*

