# 🗺️ Generador de Polígonos y Consultas de Biodiversidad

**¡NUEVA VERSIÓN INTEGRADA!** Esta aplicación web interactiva ahora permite dibujar polígonos personalizados **Y ejecutar consultas de biodiversidad directamente** en la misma interfaz, sin necesidad de scripts externos.

## 🌟 Características Principales

### ✨ **TODO EN UNO**
- 🗺️ **Dibujo interactivo** de polígonos en mapa
- 🌿 **Consultas de biodiversidad** integradas (GBIF, iNaturalist)
- 📊 **Visualización en tiempo real** de resultados
- 📈 **Gráficos y estadísticas** automáticos
- 🗺️ **Mapas de resultados** con puntos de especies
- 💾 **Exportación múltiple** de datos y resultados

### 🎯 **Sin Scripts Externos**
Ya no necesitas:
- Copiar datos a otros scripts
- Configurar manualmente APIs
- Procesar resultados por separado
- **Todo funciona en la aplicación web**

## 🚀 Inicio Rápido

### 1. Ejecutar la Aplicación
```bash
Rscript generador_poligono.R
```

### 2. Acceder a la Aplicación Web
- Abre tu navegador en la URL mostrada (ej: `http://127.0.0.1:3838`)
- La aplicación se abrirá automáticamente

### 3. Proceso Completo Integrado
1. **🗺️ Pestaña "Mapa"**: Dibuja tu polígono
2. **🌿 Pestaña "Consulta Biodiversidad"**: Ejecuta consultas
3. **📊 Pestaña "Resultados"**: Ve mapas y análisis
4. **💾 Descarga datos** en múltiples formatos

## 📱 Pestañas de la Aplicación

### 🗺️ **Pestaña "Mapa"**
- **Dibujo interactivo** haciendo clic en el mapa
- **Controles simples**: Comenzar, Finalizar, Limpiar
- **Visualización en tiempo real** del polígono
- **Exportación básica** de coordenadas

### 📊 **Pestaña "Coordenadas"**
- **Tabla detallada** de todos los vértices
- **Estadísticas** del polígono (área, bounds)
- **Exportación** en CSV, TXT, Excel

### 🌿 **Pestaña "Consulta Biodiversidad"** ⭐ **NUEVA**
- **Configuración avanzada** de consultas:
  - Tamaño de grid personalizable
  - Límites de registros por consulta
  - Selección de bases de datos (GBIF, iNaturalist)
  - Filtros taxonómicos
  - Opciones de filtrado espacial

- **Ejecución en tiempo real**:
  - Progreso de consultas visible
  - Log de actividades en vivo
  - Posibilidad de detener consultas
  - Contadores de registros y especies

### 📈 **Pestaña "Resultados"** ⭐ **NUEVA**
- **Resumen estadístico** completo
- **Mapa interactivo** con:
  - Polígono del área de estudio
  - Puntos de especies por colores (fuente)
  - Popups con información detallada
  - Control de capas por base de datos

- **Gráficos automáticos**:
  - Distribución por fuente de datos
  - Tendencias temporales por año
  - Top 10 especies más frecuentes

- **Tabla interactiva** con filtros
- **Descargas múltiples**:
  - CSV (datos tabulares)
  - Excel (con formato)
  - Shapefile (datos geoespaciales)

### 💻 **Pestaña "Datos para Scripts"**
- **Código R generado** automáticamente
- **Formato WKT** para consultas GBIF
- **Bounding boxes** para otras APIs
- **Integración** con scripts externos

## ⚙️ Configuración de Consultas

### 📐 **Parámetros del Grid**
- **Tamaño de grid**: 0.1 - 3.0 grados (default: 1.0)
- **Máximo de boxes**: 1 - 20 consultas (default: 5)
- **Registros por box**: 100 - 2000 (default: 500)

### 🗄️ **Bases de Datos Disponibles**
- **GBIF** (Global Biodiversity Information Facility)
  - Acceso a millones de registros globales
  - Filtros taxonómicos avanzados
  - Datos de museos e instituciones

- **iNaturalist** (vía spocc)
  - Observaciones de ciencia ciudadana
  - Datos con fotografías
  - Comunidad global activa

### ⚙️ **Opciones Avanzadas**
- ✅ **Solo registros con coordenadas**: Filtrar datos sin ubicación
- ✅ **Remover duplicados**: Eliminar registros repetidos
- ✅ **Filtrado espacial estricto**: Solo especies dentro del polígono
- 📅 **Rango de fechas**: Filtrar por período temporal (opcional)

## 📊 Ejemplo de Resultados en Tiempo Real

```
🔄 Ejecutando consultas... Box 3 de 5
📊 Total Registros: 847
🌿 Especies Únicas: 245
🗄️ Fuentes de Datos: 2
🗺️ Área Cubierta: 4.8 deg²

📝 Log de Consultas:
Grid generado: 5 boxes de 1.0 grados
Consultando box 1 de 5
  ✓ GBIF box 1 - agregados 312 registros
  ✓ iNat box 1 - agregados 45 registros
Consultando box 2 de 5
  ✓ GBIF box 2 - agregados 298 registros
...
✅ Query completed: 847 final records
```

## 🗺️ Visualización de Resultados

### **Mapa Interactivo**
- **Polígono del área** de estudio en verde
- **Puntos de especies** coloreados por fuente
- **Popups informativos** con detalles de cada registro
- **Control de capas** para mostrar/ocultar fuentes

### **Gráficos Automáticos**
- **Por Fuente**: Barras comparativas entre GBIF e iNaturalist
- **Por Año**: Tendencia temporal de registros
- **Top Especies**: Las 10 especies más frecuentes

### **Tabla de Resultados**
- **Filtros interactivos** por columna
- **Búsqueda global** en todos los campos
- **Ordenamiento** por cualquier columna
- **Paginación** para grandes datasets

## 💾 Formatos de Exportación

### **Desde Pestaña "Resultados"**
1. **CSV**: Datos tabulares para análisis
2. **Excel**: Con formato y múltiples hojas
3. **Shapefile**: Para uso en GIS (QGIS, ArcGIS)

### **Desde Pestaña "Coordenadas"**
1. **CSV**: Coordenadas básicas del polígono
2. **TXT**: Texto separado por tabs
3. **Excel**: Formato de hoja de cálculo

### **Desde Pestaña "Datos para Scripts"**
1. **Código R**: Listo para usar en scripts
2. **Datos WKT/Bbox**: Para integración manual

## � Instalación de Dependencias

```r
# Instalar todas las dependencias necesarias
install.packages(c(
  "shiny", "leaflet", "DT", "shinydashboard", 
  "shinyWidgets", "sf", "jsonlite", "rgbif", 
  "spocc", "dplyr", "plotly", "openxlsx"
))
```

## 🎮 Flujo de Trabajo Completo

### **Proceso Típico (5-10 minutos)**
1. **Abrir aplicación** → `Rscript generador_poligono.R`
2. **Dibujar área** → Pestaña "Mapa" → Clic en mapa
3. **Configurar consulta** → Pestaña "Consulta Biodiversidad"
4. **Ejecutar búsqueda** → Botón "Iniciar Consulta"
5. **Ver resultados** → Pestaña "Resultados" 
6. **Descargar datos** → Múltiples formatos disponibles

### **Sin Interrupciones**
- ✅ Todo en una sola aplicación
- ✅ Sin copiar/pegar entre scripts
- ✅ Resultados visuales inmediatos
- ✅ Múltiples opciones de exportación

## 📈 Ejemplos de Uso

### **Estudio de Aves Migratorias**
- Dibujar ruta migratoria
- Filtrar por familia "Aves"
- Analizar tendencias temporales
- Exportar para publicación

### **Inventario de Flora Local**
- Polígono de área protegida
- Consultar múltiples fuentes
- Identificar especies endémicas
- Generar mapa de distribución

### **Monitoreo de Biodiversidad Marina**
- Área marina específica
- Filtros por coordenadas precisas
- Datos de ciencia ciudadana
- Análisis por fuente de datos

## 🎯 Ventajas Clave

### **vs. Scripts Separados**
- ❌ **Antes**: Dibujar polígono → Exportar → Configurar script → Ejecutar → Procesar
- ✅ **Ahora**: Dibujar → Configurar → Ejecutar → **¡Resultados inmediatos!**

### **vs. Herramientas Desktop**
- ✅ **Web-based**: No instalación compleja
- ✅ **Interactivo**: Resultados en tiempo real
- ✅ **Integrado**: Todo en una herramienta
- ✅ **Moderno**: Interface intuitiva

## � Consejos y Limitaciones

### **Para Mejores Resultados**
- 🎯 **Usa polígonos moderados** (no muy grandes)
- ⚡ **Limita boxes inicialmente** (5-10 para pruebas)
- 🕐 **Ten paciencia** con consultas grandes
- 💾 **Guarda resultados** regularmente

### **Limitaciones Conocidas**
- 📊 **APIs tienen límites** de consultas por minuto
- 🌐 **Requiere conexión** a internet activa
- 💻 **Consume memoria** con datasets grandes
- ⏱️ **Tiempo de respuesta** depende de área y parámetros

## 🆘 Soporte

Si encuentras problemas:
1. **Verificar conexión** a internet
2. **Reducir tamaño** de área o número de boxes
3. **Reiniciar aplicación** si es necesario
4. **Consultar logs** en pestaña de consultas

---

**� ¡Explora la biodiversidad mundial desde tu navegador!** 🦋🌿🐦

*Combina el poder de los polígonos personalizados con las principales bases de datos de biodiversidad en una sola herramienta integrada.*
