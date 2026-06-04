# Velora Optimisation Project


## Overview

Full-stack application designed for fleet management and optimization. It consists of three main components:

- **Node.js Backend**: Handles API endpoints, authentication, and database interactions.
- **Optimization Backend**: A Python-based service for solving optimization problems related to fleet and trip management.
- **Web Frontend**: A React-based user interface for interacting with the system.

### How It Works

1. **Upload Fleet Data**: Import vehicle information and employee locations via file upload.
2. **Optimize Routes**: AI algorithms group employees into optimal carpools and calculate efficient routes.
3. **Save & Commute**: Execute optimized routes to reduce costs and provide shorter, more enjoyable commutes.

### Admin/Company Features

The platform empowers companies with powerful management tools to optimize their fleet operations:

- **Live Map Tracking**: See every vehicle and its route in real-time. Know exactly where your employees are being picked up and where they will arrive at destination.
- **Per-Fleet Dashboards**: Each fleet operates independently with its own vehicles, destination, and roster. Ideal for companies running multiple office locations or shifts.
- **Add Employees**: Assign new employees to a fleet instantly. They appear on the next scheduled route without any manual reconfiguration.
- **Remove Employees**: Offboard an employee from a fleet in one action. Their stop is dropped from all future routes immediately.
- **Delete a Fleet**: Permanently decommission a fleet when a location closes or a contract ends. All associated routes, vehicles, and employee assignments are removed cleanly.
- **Traffic Awareness**: Live traffic overlay helps dispatchers anticipate delays and communicate proactively with employees before issues arise.
- **Vehicle-Level Filters**: Handle any single vehicle or trip on the map to investigate a route, verify stops, or respond to a complaint. All fleet data is fully isolated per fleet with changes taking effect immediately across the platform.

### Employee Portal Features

Employees get a dedicated dashboard that keeps them informed about their daily commute, reducing inbound queries to your operations team:

- **Pickup Countdown**: Employees see a live timer to their next scheduled pickup — eliminating "Where is my cab?" calls to your admin team.
- **Planned Route View**: Each employee can see the assigned trip route and stops for the day, giving them full clarity on their commute before it begins.
- **Dynamic Pickup Location**: Employees can update their pickup location and pickup time at any time. The system automatically recalculates and reassigns trip based on the new position — no admin intervention needed.
- **Day-by-Day Schedule**: Staff can check their assigned pickup time and route for any day of the week from a single screen.
- **Secure Role-Based Access**: Employees can only see their own data. No employee can view or interfere with another's route or schedule.

## Folder Structure

```
Velora_optimisation_project/
├── .gitignore             # Files and folders excluded from Git
├── README.md              # This file
├── node-backend/          # Node.js backend application
│   ├── controllers/       # API controllers for different modules
│   ├── middleware/         # Authentication and other middleware
│   ├── modules/           # Database schemas and models
│   ├── routes/            # API route definitions
│   ├── utils/             # Utility functions (DB connection, multer)
│   ├── index.js           # Main server file
│   ├── package.json       # Node.js dependencies and scripts
│   ├── .env.example       # Environment variable template (safe to share)
│   └── README.md          # Backend-specific documentation
├── opti-backend/          # Python optimization backend
│   ├── dynamic.py         # Dynamic optimization logic
│   ├── main.py            # Main entry point
│   ├── map1.py            # Mapping utilities
│   ├── metrics.py         # Performance metrics
│   ├── models.py          # Data models
│   ├── solver.py          # Optimization solver
│   └── requirements.txt   # Python dependencies
└── web-frontend/          # React frontend application
    ├── public/            # Static assets
    ├── src/               # Source code
    │   ├── components/    # React components organized by feature
    │   ├── hooks/         # Custom React hooks
    │   └── utils/         # Frontend utilities
    ├── package.json       # Frontend dependencies and scripts
    ├── vite.config.js     # Vite configuration
    ├── .env.example       # Environment variable template (safe to share)
    └── README.md          # Frontend documentation
```

## What Is Included in This Repository

| Included ✅ | Purpose |
|---|---|
| `node-backend/` | All backend source code, routes, controllers, schemas |
| `opti-backend/` | All Python optimization source code |
| `web-frontend/` | All React frontend source code |
| `README.md` | Project documentation |
| `.gitignore` | Keeps secrets and generated files out of Git |
| `.env.example` files | Templates showing required environment variables |



## Prerequisites

Before running the project, ensure you have the following installed:

- **Node.js** (version 16 or higher) — [nodejs.org](https://nodejs.org/)
- **Python** (version 3.8 or higher) — [python.org](https://www.python.org/)
- **npm** (comes with Node.js)
- **pip** (Python package installer)
- **MongoDB** (local or cloud via [MongoDB Atlas](https://www.mongodb.com/atlas))
- **Git** (for cloning the repository)

## Installation and Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Velora_optimisation_project
```

### 2. Node.js Backend Setup

```bash
cd node-backend
npm install
```

Create a `.env` file by copying the template and filling in your values:

```bash
cp .env.example .env
```

Then edit `.env` with your actual credentials:

```env
JWT_SECRET="your_secret_token"
PORT=3000
MONGO_URI="your_mongodb_connection_string"
GOOGLE_CLIENT_ID="your_google_client_id"
GOOGLE_CLIENT_SECRET="your_google_client_secret"
OPTI_URL="http://localhost:8000"
FRONTEND_URL="http://localhost:5173"
CLOUDINARY_CLOUD_NAME="your_cloudinary_cloud_name"
CLOUDINARY_API_KEY="your_cloudinary_api_key"
CLOUDINARY_API_SECRET="your_cloudinary_api_secret"
```

### 3. Python Optimization Backend Setup

```bash
cd ../opti-backend
pip install -r requirements.txt
```

### 4. Web Frontend Setup

```bash
cd ../web-frontend
npm install
```

Create a `.env` file by copying the template:

```bash
cp .env.example .env
```

Then edit `.env`:

```env
VITE_BACKEND_URL=http://localhost:3000
```

## Running the Project

You need **three separate terminals** to run all services simultaneously.

### Terminal 1 — Node.js Backend

```bash
cd node-backend
npm start
```

Runs on `http://localhost:3000`.

### Terminal 2 — Python Optimization Backend

```bash
cd opti-backend
uvicorn main:app --reload --port 8000
```

Runs on `http://localhost:8000`.

### Terminal 3 — Web Frontend

```bash
cd web-frontend
npm run dev
```

Runs on `http://localhost:5173`. Open this URL in your browser.

## Usage

- Access the web application through your browser at `http://localhost:5173`.
- The frontend communicates with the Node.js backend for data operations.
- Optimization tasks are handled by the Python backend.

## Development Guidelines

- Ensure all three services are running before testing the full application.
- **Never commit `.env` files.** Use `.env.example` as a reference.
- Check individual README files in each component folder for component-specific instructions.
- Use the provided test files (e.g., `test_endpoints.js`) for API testing.
