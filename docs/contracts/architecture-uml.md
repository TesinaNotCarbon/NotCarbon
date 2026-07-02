# Smart Contract UML and Interaction Diagrams

## Contract relationship UML

```mermaid
classDiagram
    direction LR

    class RoleManager {
        +address admin
        +address upgradeController
        +mapping staff
        +initialize(admin, upgradeController)
        +addStaff(staff)
        +removeStaff(staff)
        +isStaff(user) bool
        +isStaffOrAdmin(user) bool
        +setUpgradeController(controller)
    }

    class CarbonCreditToken {
        +address admin
        +address projectManager
        +IRoleManager roleManager
        +address upgradeController
        +initialize(projectManager, roleManager, admin, upgradeController)
        +mint(amount)
        +transferTokens(recipient, amount)
        +burn(amount)
        +pause()
        +unpause()
    }

    class CompanyManager {
        +IRoleManager roleManager
        +address upgradeController
        +mapping registeredCompanies
        +address[] companyList
        +initialize(roleManager, upgradeController)
        +createCompany(name, monthlyEmissions) address
        +approveCompany(company)
        +isApproved(company) bool
        +getAllCompanies() address[]
    }

    class Company {
        -CompanyInfo info
        -address companyManagerAddress
        +owner() address
        +name() string
        +monthlyEmissions() uint256
        +carbonCredits() uint256
        +approved() bool
        +buyFromProject(project, amount)
        +buyFromMarket(market, amount)
        +approve()
        +isApproved() bool
    }

    class ProjectManager {
        +address admin
        +address upgradeController
        +IRoleManager roleManager
        +ICompanyManager companyManager
        +address validationOracleAdapter
        +mapping registeredProjects
        +mapping usedCellIds
        +mapping approvedCellIds
        +address[] projectList
        +initialize(roleManager, companyManager, admin, upgradeController)
        +registerProject(name, description, token, totalTokens, cellId) address
        +updateProjectStatus(project, newState)
        +requestProjectValidation(project) bytes32
        +receiveValidationResult(requestId, overlap, inconclusive)
        +mockValidationResult(project, overlap, inconclusive)
        +setPricePerToken(price)
        +setValidationOracleAdapter(adapter)
        +getAllProjects() address[]
    }

    class Project {
        -ProjectMeta meta
        -ProjectAccounts accounts
        -ProjectEconomics economics
        -ProjectState state
        +projectName() string
        +projectDescription() string
        +cellId() string
        +pricePerToken() uint256
        +currentState() ProjectState
        +getReleasedTokens() uint256
        +getAvailableTokens() uint256
        +buyCarbonCredits(amount)
        +buyFor(buyer, amount)
        +updateState(newState)
        +withdrawETH(amount)
    }

    class CarbonCreditMarket {
        +IProjectManager projectManager
        +ICompanyManager companyManager
        +address upgradeController
        +initialize(projectManager, companyManager, upgradeController)
        +buyFromAny(totalAmount, buyer)
        +setUpgradeController(controller)
    }

    class ReceiverTemplate {
        -address forwarderAddress
        -bytes32 expectedWorkflowId
        -address expectedAuthor
        +onReport(metadata, report)
        +setForwarderAddress(forwarder)
        +setExpectedWorkflowId(workflowId)
        +setExpectedAuthor(author)
        +getForwarderAddress() address
        #_processReport(report)*
    }

    class CREValidationOracle {
        +address admin
        +address receiver
        +uint256 requestNonce
        +mapping validationRequestExists
        +mapping validationRequestPending
        +mapping requestProject
        +mapping requestCellId
        +setReceiver(receiver)
        +isConfigured() bool
        +requestValidation(projectAddress, cellId) bytes32
        #_processReport(report)
    }

    class ChainlinkForwarder {
        <<external>>
        +onReport(metadata, report)
    }

    RoleManager <.. CarbonCreditToken : role checks
    RoleManager <.. CompanyManager : staff/admin approval
    RoleManager <.. ProjectManager : staff/admin lifecycle

    CompanyManager --> Company : deploys / approves
    CompanyManager <.. Company : only manager can approve
    CompanyManager <.. Project : verifies approved buyer
    CompanyManager <.. CarbonCreditMarket : verifies approved buyer

    ProjectManager --> Project : deploys / updates state
    ProjectManager --> CarbonCreditToken : transferTokens to project
    ProjectManager --> CREValidationOracle : requestValidation
    ProjectManager <.. CREValidationOracle : receiveValidationResult
    ProjectManager <.. CarbonCreditMarket : getAllProjects

    Project --> CarbonCreditToken : transfer CCT to buyer
    Project --> CompanyManager : isApproved in buyFor

    Company --> Project : buyCarbonCredits
    Company --> CarbonCreditMarket : buyFromAny

    CarbonCreditMarket --> Project : buyFor buyer

    CREValidationOracle --|> ReceiverTemplate : extends
    ChainlinkForwarder --> ReceiverTemplate : calls onReport
```

## Main lifecycle sequence

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    actor Staff
    actor ProjectCreator
    actor CompanyOwner
    participant RM as RoleManager
    participant CCT as CarbonCreditToken
    participant CM as CompanyManager
    participant Co as Company
    participant PM as ProjectManager
    participant P as Project
    participant Oracle as CREValidationOracle
    participant CL as Chainlink CRE Forwarder
    participant Market as CarbonCreditMarket

    Admin->>RM: addStaff(Staff)
    Staff->>CCT: mint(totalInventory)
    CCT-->>CCT: Mint CCT to token contract balance

    CompanyOwner->>CM: createCompany(name, monthlyEmissions)
    CM->>Co: new Company(owner, name, emissions, manager)
    CM-->>CompanyOwner: company address
    Staff->>CM: approveCompany(company)
    CM->>Co: approve()

    Staff->>PM: setPricePerToken(price)
    ProjectCreator->>PM: registerProject(name, description, CCT, totalTokens, cellId)
    PM->>P: new Project(...)
    PM->>CCT: transferTokens(project, totalTokens)
    CCT-->>P: Project receives CCT inventory
    PM-->>ProjectCreator: project address

    ProjectCreator->>PM: requestProjectValidation(project)
    PM->>Oracle: requestValidation(project, cellId)
    Oracle-->>PM: requestId
    CL->>Oracle: onReport(metadata, abi.encode(requestId, overlap, inconclusive))
    Oracle->>PM: receiveValidationResult(requestId, overlap, inconclusive)
    alt no overlap and not inconclusive
        PM->>P: updateState(Validated)
    else overlap or inconclusive
        PM-->>PM: store failed/inconclusive validation status
    end

    Staff->>PM: updateProjectStatus(project, Approved)
    PM->>P: updateState(Approved)
    PM-->>PM: record approved cellId

    CompanyOwner->>Co: buyFromMarket(market, amount) + ETH
    Co->>Market: buyFromAny(amount, company) + ETH
    Market->>CM: isApproved(company)
    CM->>Co: isApproved()
    loop registered projects until amount filled
        Market->>PM: getAllProjects()
        Market->>P: getAvailableTokens(), pricePerToken()
        Market->>P: buyFor(company, toBuy) + ETH
        P->>CM: isApproved(company)
        CM->>Co: isApproved()
        P->>CCT: transfer(company, toBuy)
        P-->>Market: refund excess if any
    end
    Market-->>Co: refund unused ETH
    Co-->>CompanyOwner: purchase completed
```

## Direct project purchase sequence

```mermaid
sequenceDiagram
    autonumber
    actor CompanyOwner
    participant Co as Company
    participant P as Project
    participant CCT as CarbonCreditToken

    CompanyOwner->>Co: buyFromProject(project, amount) + ETH
    Co->>P: buyCarbonCredits(amount) + ETH
    P-->>P: Check payment >= amount * price
    P-->>P: Check amount <= getAvailableTokens()
    P->>CCT: balanceOf(project)
    P->>CCT: transfer(msg.sender, amount)
    P-->>Co: Refund excess ETH
    Co-->>Co: carbonCredits += amount
```

## Validation callback sequence

```mermaid
sequenceDiagram
    autonumber
    participant PM as ProjectManager
    participant Oracle as CREValidationOracle
    participant Template as ReceiverTemplate logic
    participant CL as Chainlink CRE Forwarder
    participant P as Project

    PM->>Oracle: requestValidation(project, cellId)
    Oracle-->>Oracle: Generate requestId and mark pending
    Oracle-->>PM: requestId

    CL->>Template: onReport(metadata, report)
    Template-->>Template: Verify msg.sender == forwarder
    Template-->>Template: Optionally verify workflowId and author
    Template->>Oracle: _processReport(report)
    Oracle-->>Oracle: Decode requestId, overlap, inconclusive
    Oracle-->>Oracle: Verify request exists and is pending
    Oracle->>PM: receiveValidationResult(requestId, overlap, inconclusive)
    PM-->>PM: Mark request not pending and store status
    alt valid result
        PM->>P: updateState(Validated)
    end
```

# Simpler versions

## Contract relationship UML

```mermaid
classDiagram
    direction LR

    class RoleManager {
        +addStaff(staff)
        +isStaffOrAdmin(user) bool
    }

    class CarbonCreditToken {
        +mint(amount)
        +transferTokens(recipient, amount)
        +burn(amount)
    }

    class CompanyManager {
        +createCompany(name, monthlyEmissions) address
        +approveCompany(company)
        +isApproved(company) bool
    }

    class Company {
        +buyFromProject(project, amount)
        +buyFromMarket(market, amount)
    }

    class ProjectManager {
        +registerProject(name, description, totalTokens, cellId) address
        +updateProjectStatus(project, newState)
        +requestProjectValidation(project) bytes32
        +receiveValidationResult(requestId, overlap, inconclusive)
    }

    class Project {
        +currentState() ProjectState
        +getAvailableTokens() uint256
        +buyCarbonCredits(amount)
        +buyFor(buyer, amount)
    }

    class CarbonCreditMarket {
        +buyFromAny(totalAmount, buyer)
    }

    %% Relaciones Principales
    ProjectManager --> Project : despliega / gestiona
    CompanyManager --> Company : despliega / aprueba
    
    CarbonCreditMarket --> Project : interactúa
    Company --> CarbonCreditMarket : interactúa
    Company --> Project : interactúa

    ProjectManager --> CarbonCreditToken : distribuye inventario
    Project --> CarbonCreditToken : transfiere a comprador
```

## Main lifecycle sequence

```mermaid
sequenceDiagram
    autonumber
    actor Admin/Staff
    actor ProjectCreator
    actor CompanyOwner
    participant CM as CompanyManager
    participant PM as ProjectManager
    participant P as Project
    participant Oracle as CREValidationOracle
    participant Market as CarbonCreditMarket

    %% Fase de Configuración
    Admin/Staff->>CM: approveCompany(companyAddress)
    
    %% Registro y Validación
    ProjectCreator->>PM: registerProject(name, tokenAmount, cellId)
    PM->>P: Despliega nuevo Project (con inventario de tokens)
    
    ProjectCreator->>PM: requestProjectValidation(project)
    PM->>Oracle: requestValidation(project, cellId)
    note right of Oracle: Proceso Off-Chain (dMRV)
    Oracle->>PM: receiveValidationResult(overlap: false)
    PM->>P: updateState(Validated)
    Admin/Staff->>PM: updateProjectStatus(project, Approved)

    %% Mercado
    CompanyOwner->>Market: buyFromAny(amount) + ETH
    Market->>CM: isApproved(company)
    loop Hasta completar monto
        Market->>P: buyFor(company, amount) + ETH
        P->>P: Transfiere CarbonCreditTokens a Company
    end
    Market-->>CompanyOwner: Créditos asignados (y ETH sobrante reembolsado)
```

## Direct project purchase sequence

```mermaid
sequenceDiagram
    autonumber
    actor CompanyOwner
    participant Co as Company
    participant P as Project
    participant CCT as CarbonCreditToken

    CompanyOwner->>Co: buyFromProject(project, amount) + ETH
    Co->>P: buyCarbonCredits(amount) + ETH
    
    %% Lógica On-Chain simplificada
    P->>CCT: transfer(CompanyOwner, amount)
    CCT-->>Co: Balance de tokens actualizado
    
    P-->>CompanyOwner: Reembolso de ETH excedente (si aplica)
```

## Validation callback sequence

```mermaid
sequenceDiagram
    autonumber
    participant PM as ProjectManager
    participant Oracle as CREValidationOracle
    participant CL as Chainlink Node (Off-Chain)
    participant P as Project

    %% Solicitud
    PM->>Oracle: requestValidation(project, cellId)
    Oracle-->>CL: Emite evento de solicitud (Event Log)
    
    note over CL: Ejecución de algoritmos geoespaciales
    
    %% Respuesta asíncrona
    CL->>Oracle: onReport(requestId, overlap, inconclusive)
    Oracle->>PM: receiveValidationResult(requestId, overlap, inconclusive)
    
    alt Resultado Válido (Sin superposición)
        PM->>P: updateState(Validated)
    else Superposición detectada
        PM-->>PM: Registra estado fallido
    end
```
