Project Theme – CareCoins:

A Web-Based Family Care Management System that accounts for transparent sharing of responsabilities


Project Description:

CareCoins is a web application that models family caregiving and household task distribution as a coin-based system which can be easily track and transparently shred. Each activity generates coin movements affecting both individual user balances and the overall family balance.
The system is designed around strong backend logic, including balance invariants, activity state transitions, and time-slot validation. The goal of the project is to implement a consistent, rule-driven system that ensures fairness and traceability of care contributions within a family, making really visible who and when is taking the majority of the responsibility and the price it implies.

Functional & technical scope:

The app will provide from a funtional user perspective:

1.	User registration and authentication.
2.	Family creation and joining workflow.
3.	Role management within families.
4.	Activity creation with:
4.1.	Minimum duration constraints.
4.2.	Time-slot validation (no overlapping activities).
4.3.	Categorization (care vs household tasks).
4.4.	Activity approval workflow by main caregivers.
5.	Coin accounting logic:
5.1.	Individual balance updates.
5.2.	Family-level balance tracking.
5.3.	Monthly unit recalculation logic.
6.	Dashboard with:
6.1.	Individual balances.
6.2.	Family balance status.
6.3.	Calendar visualization of activities.
7.	Marketplace for coin exchange.



From a technical perspective, the main points will be:

1.	Definition of relational schema in PostgreSQL.
2.	Enforcement of transactional consistency.
3.	State machine implementation for activity lifecycle.
4.	Separation between frontend presentation layer and backend business logic.
5.	API design and validation.

Technology Stack and Technical Architecture

•	Frontend: Vue.js
o	State Management: Pinia
o	Dashboarding: TBD
•	Backend: Node.js with Express
•	Database: PostgreSQL
•	Authentication: Firebase Authentication
•	Deployment: Dockerized services on a home web server, exposed via Cloudflare Tunnel

Vue and PWA Support: The frontend will be implemented using Vue.js with PWA capabilities enabled through a service worker configuration (via tools such as Vite PWA plugin or Vue CLI PWA support).

Backend Architecture: The backend will be implemented using Node.js with Express, exposing RESTful API endpoints responsible for:
•	Activity lifecycle management.
•	Coin transaction logic.
•	Family and user management.
•	Enforcement of business rules.
•	All critical operations affecting balances will be executed within PostgreSQL transactions to ensure atomicity and prevent inconsistent states.

Database Design:The system will use a relational model including tables such as:
•	users
•	families
•	actors
•	activities
•	login_history
Foreign key constraints and transactional queries will enforce data integrity and maintain balance invariants.

Authentication: Firebase Authentication will manage identity and token issuance. The backend will verify Firebase ID tokens on each request to ensure secure access control.

Deployment:The application will be containerized using Docker with following containers:
1.	Vue frontend (served via Nginx).
2.	Node/Express backend.
3.	PostgreSQL.
All services will run on a home server and will be securely exposed to the internet using Cloudflare Tunnel, avoiding direct port exposure and improving security
