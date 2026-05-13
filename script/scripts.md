# Scripts de deploy y setup

Este documento describe que hacen los scripts de deploy y setup, sus precondiciones, variables de entorno y el flujo actual.

## Deploy.s.sol

### Que hace
- Despliega los contratos base en el orden correcto.
- Configura el precio por token en el ProjectManager.
- Minta tokens en el CarbonCreditToken hacia la propia address del token.
- Muestra por consola las direcciones desplegadas y parametros usados.

### Flujo
1. Lee `PRIVATE_KEY`, `PRICE_PER_TOKEN` y `MINT_AMOUNT`.
2. Despliega: RoleManager, CompanyManager, ProjectManager, CarbonCreditToken, CarbonCreditMarket.
3. Setea `pricePerToken` en ProjectManager.
4. Minta `MINT_AMOUNT` en el CarbonCreditToken (a la address del contrato).
5. Loggea direcciones y parametros.

### Variables de entorno
- `PRIVATE_KEY` (requerida): clave del deployer.
- `PRICE_PER_TOKEN` (opcional, default 10): precio inicial por token.
- `MINT_AMOUNT` (opcional, default 10000): cantidad de tokens a mintear.

### Precondiciones y permisos
- El deployer queda como admin del RoleManager.
- `setPricePerToken` requiere staff o admin; el deployer es admin.
- `mint` requiere staff o admin; el deployer es admin.

### Salida esperada
- Direcciones de todos los contratos y valores de `PricePerToken` y `MintAmount`.

```
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

## Setup.s.sol

### Que hace
- Configura roles (agrega staff si se provee).
- Setea `pricePerToken`.
- Minta tokens asegurando que cubra el total de tokens de los proyectos a crear.
- Configura Chainlink (opcional).
- Crea dos proyectos con distintos estados: uno queda sin aprobar y el otro avanza a `Milestone1` si se habilita mock.

### Flujo
1. Lee addresses de contratos existentes (`ROLE_MANAGER_ADDRESS`, `PROJECT_MANAGER_ADDRESS`, `CARBON_CREDIT_TOKEN_ADDRESS`).
2. Agrega staff si `STAFF_ADDRESS` esta definido y no es staff.
3. Setea `pricePerToken`.
4. Si `SETUP_PROJECTS=1`, calcula el mint minimo requerido por la suma de tokens de ambos proyectos.
5. Minta tokens si `MINT_AMOUNT > 0`.
6. Si `SET_CHAINLINK=1`, configura el oracle y deshabilita el mock.
7. Si `SETUP_PROJECTS=1`, registra dos proyectos.
8. Si `ADVANCE_PROJECT2=1` y `MOCK_VALIDATION=1`, valida por mock y avanza el segundo proyecto a `Approved` y `Milestone1`.

### Variables de entorno basicas
- `PRIVATE_KEY` (requerida)
- `ROLE_MANAGER_ADDRESS` (requerida)
- `PROJECT_MANAGER_ADDRESS` (requerida)
- `CARBON_CREDIT_TOKEN_ADDRESS` (requerida)
- `STAFF_ADDRESS` (opcional)
- `PRICE_PER_TOKEN` (opcional, default 10)
- `MINT_AMOUNT` (opcional, default 10000; se ajusta al total de tokens de proyectos si es menor)

### Variables de entorno para proyectos
- `SETUP_PROJECTS` (opcional, default 1)
- `PROJECT1_NAME` (default "Reforestacion A")
- `PROJECT1_DESCRIPTION` (default "Proyecto inicial")
- `PROJECT1_TOKENS` (default 1000)
- `PROJECT1_CELL_ID` (default "cell-1")
- `PROJECT2_NAME` (default "Eolico B")
- `PROJECT2_DESCRIPTION` (default "Proyecto en fase 1")
- `PROJECT2_TOKENS` (default 2000)
- `PROJECT2_CELL_ID` (default "cell-2")
- `ADVANCE_PROJECT2` (opcional, default 1)
- `MOCK_VALIDATION` (opcional, default 1)

### Variables de entorno para Chainlink
- `SET_CHAINLINK` (opcional, default 0)
- `CHAINLINK_LINK_TOKEN`
- `CHAINLINK_ORACLE`
- `CHAINLINK_JOB_ID`
- `CHAINLINK_FEE`

### Precondiciones y permisos
- `setPricePerToken` requiere staff o admin.
- `mint` requiere staff o admin.
- `mockValidationResult` requiere admin y solo funciona si no hay oracle configurado.
- Para avanzar a `Approved` es obligatorio que el proyecto este `Validated`.

### Salida esperada
- Direcciones de RoleManager, ProjectManager, Token.
- Confirmacion de staff (si aplica).
- `PricePerToken`, `MintAmount`.
- Direcciones de Project1 y Project2.
- Estado de Project2 si se avanzo a `Milestone1`.

## SmokeTest.s.sol

### Que hace
- Ejecuta un flujo end-to-end para validar el camino feliz.
- Registra un proyecto si no existe y lo valida (mock si no hay oracle).
- Avanza el proyecto a `Milestone4`.
- Crea y aprueba una empresa.
- Compra tokens desde el market.

### Flujo
1. Lee addresses base (`PROJECT_MANAGER_ADDRESS`, `COMPANY_MANAGER_ADDRESS`, `TOKEN_ADDRESS`, `MARKET_ADDRESS`).
2. Registra proyecto si `PROJECT_ADDRESS` no esta definido.
3. Valida proyecto via mock si no hay oracle; si hay oracle, dispara la request y corta el script.
4. Avanza el proyecto a `Approved` y milestones hasta `Milestone4`.
5. Crea empresa si `COMPANY_ADDRESS` no esta definido y la aprueba.
6. Compra tokens desde el market por el monto indicado.

### Variables de entorno basicas
- `PRIVATE_KEY` (requerida)
- `PROJECT_MANAGER_ADDRESS` (requerida)
- `COMPANY_MANAGER_ADDRESS` (requerida)
- `TOKEN_ADDRESS` (requerida)
- `MARKET_ADDRESS` (requerida)
- `BUY_AMOUNT` (opcional, default 10)

### Variables de entorno para proyecto/empresa
- `PROJECT_ADDRESS` (opcional)
- `PROJECT_NAME` (default "SmokeProject")
- `PROJECT_DESCRIPTION` (default "Smoke test project")
- `PROJECT_TOTAL_TOKENS` (default 1000)
- `PROJECT_CELL_ID` (default "CELL-SMOKE-001")
- `COMPANY_ADDRESS` (opcional)
- `COMPANY_NAME` (default "SmokeCompany")
- `COMPANY_MONTHLY_EMISSIONS` (default 100)

### Salida esperada
- Direcciones de Project y Company.
- `BuyAmount` y `TotalCost`.

## Ejemplo rapido (anvil/local)

## Secuencia recomendada (anvil -> deploy -> setup)

1) Levanta anvil en una terminal:

```bash
anvil
```

2) Despliega los contratos en la misma red:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

3) Exporta las direcciones que imprime el deploy:

```bash
export ROLE_MANAGER_ADDRESS=0x...
export PROJECT_MANAGER_ADDRESS=0x...
export CARBON_CREDIT_TOKEN_ADDRESS=0x...
```

4) Ejecuta el setup en la misma red:

```bash
forge script script/Setup.s.sol:Setup --rpc-url http://127.0.0.1:8545 --broadcast
```

```bash
export PRIVATE_KEY=0x...
export ROLE_MANAGER_ADDRESS=0x...
export PROJECT_MANAGER_ADDRESS=0x...
export CARBON_CREDIT_TOKEN_ADDRESS=0x...
export PRICE_PER_TOKEN=10
export SETUP_PROJECTS=1
export MOCK_VALIDATION=1
export ADVANCE_PROJECT2=1

forge script script/Setup.s.sol:Setup --rpc-url http://127.0.0.1:8545 --broadcast
```

