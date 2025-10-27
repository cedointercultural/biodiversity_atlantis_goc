#!/bin/bash

# ============================================================================
# Script: run_maxima_screen.sh
# Descripción: Ejecuta consulta máxima en screen con auto-apagado
# Fecha: 2025-10-22
# ============================================================================

cd /home/atlantis/biodiversity_atlantis_goc

echo "═══════════════════════════════════════════════════════════════"
echo "🚀 CONFIGURANDO EJECUCIÓN EN SCREEN CON AUTO-APAGADO"
echo "═══════════════════════════════════════════════════════════════"
echo "📅 Inicio: $(date)"
echo "📁 Directorio: $(pwd)"
echo "⚙️  Script: scripts/biodiversity_query.R (modo parallel)"
echo "🔢 Registros por celda: 15,000"
echo "🗃️ Bases de datos: GBIF, OBIS, iDigBio, iNaturalist"
echo "⚡ Procesamiento: Paralelo (future + furrr)"
echo "⏱️ Tiempo estimado: 20-30 minutos"
echo "🔌 Auto-apagado: SÍ (al completar)"
echo "═══════════════════════════════════════════════════════════════"

# Crear directorio de logs
mkdir -p logs

# Terminar sesiones screen existentes
screen -X -S biodiversity_query quit 2>/dev/null || echo "No hay sesiones previas"

# Crear nueva sesión screen con el script completo
screen -dmS biodiversity_query bash -c "
    cd /home/atlantis/biodiversity_atlantis_goc
    
    echo '🚀 INICIANDO CONSULTA MÁXIMA PARALELA EN SCREEN'
    echo '═══════════════════════════════════════════════════════════════'
    echo '📅 Inicio:' \$(date)
    echo '📍 Polígono: shapefiles/study_zone.gpkg'
    echo '🎯 Bases de datos: GBIF, OBIS, iDigBio, iNaturalist'
    echo '📊 Registros por celda: 15,000'
    echo '📅 Período: 2000-2025 (25 años)'
    echo '⚡ Procesamiento: Paralelo estable'
    echo '═══════════════════════════════════════════════════════════════'
    echo ''
    
    # Ejecutar consulta con timestamp en log
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    LOG_FILE=\"logs/maxima_query_\${TIMESTAMP}.log\"
    
    echo \"📝 Log file: \$LOG_FILE\"
    echo \"🔍 Para monitorear: tail -f \$LOG_FILE\"
    echo ''
    
    # Ejecutar la consulta y capturar el resultado
    Rscript -e \"
        cat('🔥 PROCESO INICIADO EN SCREEN\\n')
        cat('═══════════════════════════════════════════════════════════════\\n')
        cat('⏰ Hora inicio:', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), '\\n')
        cat('📂 Directorio:', getwd(), '\n')
        if (requireNamespace('parallel', quietly = TRUE)) {
            cat('🧠 Núcleos disponibles:', parallel::detectCores(), '\n')
        }
        cat('═══════════════════════════════════════════════════════════════\\n\\n')
        
        # Cambiar al directorio de trabajo
        setwd('/home/atlantis/biodiversity_atlantis_goc')
        
        # Cargar y ejecutar el script
        source('scripts/biodiversity_query.R')
        
        cat('\\n🚀 Ejecutando consulta máxima paralela...\\n\\n')
        results <- run_biodiversity_query('parallel')
        
        cat('\\n\\n')
        cat('═══════════════════════════════════════════════════════════════\\n')
        cat('✅ CONSULTA COMPLETADA EXITOSAMENTE\\n')
        cat('═══════════════════════════════════════════════════════════════\\n')
        cat('⏰ Hora fin:', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), '\\n')
        
        # Mostrar resumen si hay resultados
        if (!is.null(results) && !is.null(results\$results) && nrow(results\$results) > 0) {
            cat('📊 Registros obtenidos:', nrow(results\$results), '\\n')
            if ('database' %in% colnames(results\$results)) {
                cat('📈 Por base de datos:\\n')
                db_summary <- table(results\$results\$database)
                for (db in names(db_summary)) {
                    cat('   •', db, ':', db_summary[db], 'registros\\n')
                }
            }
        }
        
        cat('\\n🎉 PROCESO COMPLETADO - PREPARANDO AUTO-APAGADO\\n')
        cat('═══════════════════════════════════════════════════════════════\\n')
    \" 2>&1 | tee \"\$LOG_FILE\"
    
    RESULT_CODE=\${PIPESTATUS[0]}
    
    echo ''
    echo '═══════════════════════════════════════════════════════════════'
    if [ \$RESULT_CODE -eq 0 ]; then
        echo '✅ PROCESO COMPLETADO EXITOSAMENTE'
        echo '📁 Archivos generados en: data/query_results/'
        ls -la data/query_results/biodiversity_*\$(date +%Y%m%d)* 2>/dev/null || echo '   (Verificar archivos manualmente)'
    else
        echo '❌ PROCESO TERMINÓ CON ERRORES (Código: '\$RESULT_CODE')'
        echo '📝 Revisar log para detalles: '\$LOG_FILE
    fi
    echo '⏰ Hora finalización:' \$(date)
    echo '═══════════════════════════════════════════════════════════════'
    echo ''
    echo '🔌 INICIANDO SECUENCIA DE AUTO-APAGADO...'
    echo '⏳ Esperando 30 segundos antes del apagado...'
    echo '❗ PRESIONA Ctrl+C AHORA SI QUIERES CANCELAR EL APAGADO'
    
    # Countdown de 30 segundos
    for i in {30..1}; do
        echo \"🕐 Apagado en \$i segundos... (Ctrl+C para cancelar)\"
        sleep 1
    done
    
    echo ''
    echo '🔌 APAGANDO MÁQUINA VIRTUAL...'
    echo '👋 ¡Hasta la vista!'
    
    # Apagar la máquina
    sudo shutdown -h now
"

echo ""
echo "✅ SESIÓN SCREEN CREADA EXITOSAMENTE"
echo ""
echo "📋 INFORMACIÓN DE LA SESIÓN:"
echo "   🆔 Nombre: biodiversity_query"
echo "   📝 Log: logs/maxima_query_[timestamp].log"
echo "   🔌 Auto-apagado: Activado (30 seg después de completar)"
echo ""
echo "🔧 COMANDOS ÚTILES:"
echo "   • Ver sesiones:        screen -ls"
echo "   • Reconectar:          screen -r biodiversity_query"
echo "   • Monitorear log:      tail -f logs/maxima_query_*.log"
echo "   • Detener proceso:     screen -X -S biodiversity_query quit"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   • El proceso continuará aunque cierres VS Code"
echo "   • La máquina se apagará automáticamente al terminar"
echo "   • Puedes reconectarte en cualquier momento con screen -r"
echo ""
echo "🚀 PROCESO INICIADO - PUEDES DESCONECTARTE AHORA"
echo "═══════════════════════════════════════════════════════════════"