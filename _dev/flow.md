flowchart TD

%% Core objects
GM[GameManager autoload]
GM_RULES[GameManager rules<br/>Scenes only depend on GameManager<br/>GameManager delegates internally to small modules]

BM[Behavior Matrix]
ADB[AssetDB tres]
IDB[Indicator DB tres]
IAR[Individual Asset Resources]
IIR[Individual Indicator Resources]
SG[ScenarioGenerator]
TEL[Telemetry]

GM_RULES -.-> GM

GM --> BM
GM --> TEL
BM --> ADB
BM --> IDB
ADB --> IAR
IDB --> IIR
BM --> SG

%% GameManager modules shown as rectangles
SAS[Set App Settings]
RWAS[Read Write App Settings]
RSTAT[Read Stats]
RRES[Read Results]
SRP[Start Run Practice Load Profile Info]
SPP[Start Practice with chosen params]
MAPI[Get current match view model and send player actions]

GM --> SAS
GM --> RWAS
GM --> RSTAT
GM --> RRES
GM --> SRP
GM --> SPP
GM --> MAPI

%% Scenes and flow
BNU[Brand New User]
RU[RunSetup tscn<br/>Select time horizon<br/>Select difficulty]
START[Start Button]
RET[Returning User]

MM[MainMenu tscn<br/>Life cycle begins]
SET[Settings tscn<br/>Restart life<br/>Reset time horizon<br/>Set difficulty]
PRO[Profile tscn]

PS[PracticeSelect tscn<br/>Select assets and indicators to practice]
PM[PracticeMatch tscn<br/>Play practice]
EPO[End Practice Overlay]

SRUI[StartRunUI tscn<br/>Select assets]
MATCH[Match tscn<br/>Play level]
EMO[End Match Overlay]

BNU --> RU --> START --> MM
RET --> MM

MM --> SET
MM --> PRO
MM --> PS
PS --> PM --> EPO --> PS

MM --> SRUI --> MATCH --> EMO --> SRUI

%% Scene dependencies on GameManager
RU -.-> GM
MM -.-> GM
SET -.-> GM
PRO -.-> GM
PS -.-> GM
PM -.-> GM
EPO -.-> GM
SRUI -.-> GM
MATCH -.-> GM
EMO -.-> GM

%% Scene to module touchpoints
RU --> SAS
RU --> RWAS
SET --> RWAS
PRO --> RSTAT
MM --> RRES
PS --> SPP
SRUI --> SRP
MATCH --> MAPI