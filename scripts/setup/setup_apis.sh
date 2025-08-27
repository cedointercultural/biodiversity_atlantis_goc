#!/bin/bash

# Script de configuración para APIs de biodiversidad
# Este script te ayuda a configurar las claves API necesarias

echo "🔧 Configurador de APIs para Biodiversidad Atlantis GoC"
echo "======================================================"
echo

# Función para configurar eBird API
setup_ebird() {
    echo "📦 Configurando eBird API..."
    echo
    
    if [ -f "ebirdapi_key" ]; then
        echo "⚠️  Ya existe un archivo 'ebirdapi_key'"
        read -p "¿Quieres reemplazarlo? (y/n): " replace
        if [[ $replace != [yY] ]]; then
            echo "✅ Configuración de eBird cancelada"
            return
        fi
    fi
    
    echo "1. Ve a: https://ebird.org/api/keygen"
    echo "2. Crea una cuenta gratuita si no tienes una"
    echo "3. Copia tu clave API"
    echo
    
    read -p "Pega tu clave API de eBird aquí: " ebird_key
    
    if [ -z "$ebird_key" ]; then
        echo "❌ No se proporcionó ninguna clave. Configuración cancelada."
        return
    fi
    
    echo "$ebird_key" > ebirdapi_key
    echo "✅ Clave de eBird guardada en 'ebirdapi_key'"
    echo "🔒 Este archivo está protegido por .gitignore"
}

# Función para verificar configuración
verify_setup() {
    echo "🔍 Verificando configuración..."
    echo
    
    if [ -f "ebirdapi_key" ]; then
        key=$(head -n 1 ebirdapi_key | tr -d '[:space:]')
        if [ -n "$key" ] && [ "$key" != "tu_clave_ebird_api_aqui" ]; then
            echo "✅ eBird API: Configurado correctamente"
        else
            echo "❌ eBird API: Archivo existe pero clave no válida"
        fi
    else
        echo "⚠️  eBird API: No configurado (archivo 'ebirdapi_key' no encontrado)"
    fi
    
    echo
    echo "📊 Bases de datos disponibles:"
    echo "  ✅ GBIF (no requiere API key)"
    echo "  ✅ iDigBio (no requiere API key)"
    if [ -f "ebirdapi_key" ]; then
        echo "  ✅ eBird (configurado)"
    else
        echo "  ⚠️  eBird (requiere configuración)"
    fi
    echo "  ⚠️  iNaturalist (servicio temporalmente no disponible)"
    echo "  ⚠️  OBIS (requiere ajustes técnicos)"
}

# Función principal
main() {
    case "$1" in
        "ebird"|"eBird")
            setup_ebird
            ;;
        "verify"|"check")
            verify_setup
            ;;
        "")
            echo "Opciones disponibles:"
            echo "  $0 ebird    - Configurar eBird API"
            echo "  $0 verify   - Verificar configuración"
            echo
            read -p "¿Qué quieres hacer? (ebird/verify): " choice
            case "$choice" in
                "ebird"|"eBird")
                    setup_ebird
                    ;;
                "verify"|"check")
                    verify_setup
                    ;;
                *)
                    echo "❌ Opción no válida"
                    ;;
            esac
            ;;
        *)
            echo "❌ Opción no reconocida: $1"
            echo "Uso: $0 [ebird|verify]"
            exit 1
            ;;
    esac
}

main "$1"
