# ⚠️ INSTRUCCIONES CRÍTICAS: API KEYS PARA PRODUCCIÓN

**Última actualización:** 2026-10-01  
**Responsable:** Roberto Valladares  

---

## 🚨 REGLA OBLIGATORIA: NUNCA COMMITEAR API KEYS

**NUNCA bajo ninguna circunstancia commitear o pushear archivos `.env` o credenciales al repositorio.**

```bash
# ✅ CORRECTO: Las claves están en el servidor, no en Git
SERPER_API_KEY=nBqXdVw6F3iEs1HwRSWXdZuR

# ❌ INCORRECTO: Nunca en archivos versionados
echo "SERPER_API_KEY=nBqXdVw6F3iEs1HwRSWXdZuR" >> .env
git add .env
git commit -m "Add API key"  # 🚨 ESTO NUNCA
```

---

## 📋 API KEYS REQUERIDAS

### 1. SERPER_API_KEY (Búsqueda de Noticias)

**Propósito:** Realizar búsquedas automáticas en Google News para encontrar artículos sobre sanciones OFAC

**Clave:** `nBqXdVw6F3iEs1HwRSWXdZuR`

**Usado en:** 
- `/scripts/ofac_pipeline_executor.rb` - PASO 2 (búsqueda de cartel)
- `app/controllers/agent_controller.rb` - búsquedas de detenciones

**Endpoint:** `https://google.serper.dev/news`

---

## 🔧 CONFIGURACIÓN POR ENTORNO

### Desarrollo (Local)

**Opción A: Archivo `.env` (Local Only)**
```bash
# .env (NUNCA en Git)
SERPER_API_KEY=nBqXdVw6F3iEs1HwRSWXdZuR
```

**Opción B: Variable de entorno directa**
```bash
export SERPER_API_KEY='nBqXdVw6F3iEs1HwRSWXdZuR'
rails runner script.rb
```

**Verificación:**
```bash
rails runner "puts ENV['SERPER_API_KEY']"
# Output: nBqXdVw6F3iEs1HwRSWXdZuR
```

### Producción (AWS EC2)

**NUNCA usar `.env` en producción. Usar AWS Systems Manager Parameter Store:**

```bash
# 1. En AWS console o AWS CLI, guardar la clave:
aws ssm put-parameter \
  --name /lantiaintelligence/ofac/serper-api-key \
  --value 'nBqXdVw6F3iEs1HwRSWXdZuR' \
  --type SecureString \
  --region us-east-2

# 2. En el servidor, leer al iniciar la aplicación:
export SERPER_API_KEY=$(aws ssm get-parameter \
  --name /lantiaintelligence/ofac/serper-api-key \
  --query 'Parameter.Value' \
  --with-decryption \
  --region us-east-2 \
  --output text)

# 3. Iniciar Rails con la variable
rails server
```

---

## ✅ CHECKLIST: ANTES DE SUBIR A PRODUCCIÓN

- [ ] **NO commitear `.env`** - Usar `.env.example` para documentar variables
- [ ] **NO commitear credenciales** - Verificar `git log` no tiene claves
- [ ] **Verificar `.gitignore`** contiene `.env*`
- [ ] **Guardar API key en AWS Parameter Store**, no en código
- [ ] **Probar acceso a SERPER** desde el servidor de producción
- [ ] **Usar variables de entorno** para obtener la clave
- [ ] **Rotar API keys** cada 90 días (actualizar en AWS Parameter Store)
- [ ] **Documentar dónde está guardada** cada clave (para equipo)
- [ ] **Revisar logs** para asegurar que API key NO aparece en output
- [ ] **Ejecutar test** con datos reales ANTES de deploy

---

## 🔍 VERIFICACIÓN: API KEY FUNCIONANDO

```bash
# Desarrollo (Local)
export SERPER_API_KEY='nBqXdVw6F3iEs1HwRSWXdZuR'
rails runner /scripts/ofac_pipeline_executor.rb

# Debe mostrar:
# ✅ PASO 1: Candidato disponible
# ✅ PASO 2: Búsqueda ejecutada en Serper
# ✅ Query exacta: [búsqueda realizada]
```

---

## 🚨 SEGURIDAD: Si la API key se expone

**Acciones inmediatas:**
1. Revocar la API key en Serper dashboard
2. Generar nueva API key
3. Actualizar en AWS Parameter Store
4. Verificar uso no autorizado en logs de Serper
5. Informar al equipo

---

## 📝 NOTAS

- **No compartir por Slack, Email o Chat** - Solo en AWS Parameter Store
- **No pedir la API key por chat** - Siempre obtenerla del Parameter Store
- **Rotar regularmente** - Cambiar cada 90 días
- **Monitorear uso** - Verificar costos en Serper dashboard
- **Auditar logs** - Asegurar que la clave no aparece en los registros

---

**Responsabilidad:** Cada desarrollador es responsable de no exponer credenciales.  
**Consecuencias:** Exposición de credenciales = revisión de seguridad obligatoria.
