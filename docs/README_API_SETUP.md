# 🔑 Configuración de APIs para Biodiversidad

Este documento explica cómo configurar las claves API necesarias para acceder a todas las bases de datos de biodiversidad.

## 📦 Bases de Datos Disponibles

| Base de Datos | API Key Requerida | Estado |
|---------------|-------------------|--------|
| **GBIF** | ❌ No | ✅ Funcionando |
| **iDigBio** | ❌ No | ✅ Funcionando |
| **eBird** | ✅ Sí | ⚠️ Requiere configuración |
| **iNaturalist** | ❌ No | ⚠️ Servicio temporalmente no disponible |
| **OBIS** | ❌ No | ⚠️ Requiere ajustes técnicos |

## 🚀 Configuración Rápida

### Método 1: Script Automático (Recomendado)
```bash
# Ejecutar el configurador interactivo
./setup_apis.sh

# O directamente configurar eBird
./setup_apis.sh ebird

# Verificar configuración
./setup_apis.sh verify
```

### Método 2: Manual

#### eBird API
1. **Obtener clave API:**
   - Ve a: https://ebird.org/api/keygen
   - Crea una cuenta gratuita (si no tienes una)
   - Copia tu clave API

2. **Configurar en el proyecto:**
   ```bash
   # Crear archivo con tu clave API
   echo "tu_clave_real_aqui" > ebirdapi_key
   ```

3. **Verificar:**
   - El archivo `ebirdapi_key` debe contener solo tu clave API
   - Este archivo está protegido por `.gitignore` para tu seguridad

## 🔒 Seguridad

- ✅ El archivo `ebirdapi_key` está incluido en `.gitignore`
- ✅ Nunca subas tus claves API al repositorio
- ✅ Si compartes el código, copia `ebirdapi_key.example` como referencia

## 🎯 Prioridades de Configuración

El sistema busca la clave API de eBird en este orden:

1. **Campo en la interfaz web** (mayor prioridad)
2. **Archivo `ebirdapi_key`** (recomendado para uso local)
3. **Variable de entorno `EBIRD_KEY`** (menor prioridad)

## 🛠️ Solución de Problemas

### eBird no funciona
```bash
# Verificar que el archivo existe
ls -la ebirdapi_key

# Verificar contenido (sin mostrar la clave completa)
head -c 10 ebirdapi_key && echo "..."

# Reconfigurar
./setup_apis.sh ebird
```

### Verificar configuración general
```bash
./setup_apis.sh verify
```

## 📁 Archivos Importantes

- `ebirdapi_key` - Tu clave API de eBird (no versionar)
- `ebirdapi_key.example` - Plantilla de ejemplo (versionar)
- `setup_apis.sh` - Script de configuración
- `.gitignore` - Protege tus claves API

## 🚀 Uso

Una vez configurado, simplemente ejecuta tu aplicación:

```bash
# Ejecutar la aplicación principal
Rscript generador_poligono.R
```

La aplicación detectará automáticamente tu configuración y usará todas las bases de datos disponibles.
