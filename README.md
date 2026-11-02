<div align="center">

# 🟠 Atyro Panel

### Minecraft Server Management Panel

**A modern web panel for managing Minecraft servers from one place.**

![Version](https://img.shields.io/badge/version-1.0.0-orange?style=for-the-badge)
![Author](https://img.shields.io/badge/author-Atyro%20Labs-black?style=for-the-badge)
![Runtime](https://img.shields.io/badge/Node.js-Required-339933?style=for-the-badge&logo=node.js&logoColor=white)
![Database](https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

</div>

---

## 📖 About

**Atyro Panel v1.0.0** is a web-based Minecraft server management panel developed by **Atyro Labs**. It brings common server administration tasks into a single interface, with a backend designed to communicate with remote nodes for server operations.

The project uses Node.js, Express, EJS, SQLite, and Socket.IO to provide its web application, data storage, and real-time communication components.

> **Project:** Atyro Panel  
> **Version:** `v1.0.0`  
> **Author:** Atyro Labs  
> **Type:** Minecraft Server Management Panel

## ✨ Features

Features represented in the current application code include:

- 🖥️ **Server management** — manage server records, configuration, resource allocations, and status.
- 🌐 **Remote-node architecture** — server actions and server file operations are designed to be handled by remote node agents.
- 🎮 **Multiple server software options** — includes support definitions for Vanilla, Paper, Purpur, Spigot, CraftBukkit, Fabric, Forge, Quilt, Velocity, BungeeCord, and Waterfall.
- 📦 **Minecraft version and build lookup** — fetches available versions/build information from supported upstream APIs where implemented.
- 📟 **Live console and logs** — Socket.IO-based real-time communication and server log handling.
- 📊 **Resource monitoring** — server statistics and live-stat update components.
- 📁 **File and backup management** — database structures and application components for server files, backups, and file activity.
- 👥 **User accounts and roles** — user records, roles, profiles, and account status.
- 🔐 **Session-based authentication** — Express sessions, password hashing, and authenticated Socket.IO connections.
- 🧑‍🤝‍🧑 **Sub-user permissions** — support structures for assigning permissions to additional users on a server.
- 🔔 **Notifications** — user notifications, read status, and notification preferences.
- ⚙️ **Panel settings** — persistent settings stored in SQLite.
- 🧾 **Application logging** — console and file logging, including request error logging.

*The availability of an individual feature depends on the complete project files and any required remote node agent configuration.*

## 🧰 Technology Stack

| Component | Technology |
| --- | --- |
| Backend | Node.js |
| Web framework | Express |
| Templates | EJS |
| Database | SQLite |
| Real-time communication | Socket.IO |
| Authentication utilities | express-session, bcryptjs |
| Upload handling | Multer |
| Archive handling | Archiver, Unzipper |
| HTTP requests | Axios |
| Minecraft data parsing | prismarine-nbt |

## 📋 Requirements

Before installing, prepare:

- A supported Node.js LTS release
- npm (included with Node.js)
- The complete Atyro Panel project files
- The project's required npm dependencies
- A configured remote node agent for server operations
- Network access for the Minecraft software/version APIs you use

Use a Linux server for a typical hosted deployment. Confirm the project's Node.js and operating-system compatibility before putting it into production.

## 🚀 Installation

### 1. Get the project

Clone your repository, or upload and extract the project files to your server.

```bash
git clone YOUR_REPOSITORY_URL
cd YOUR_PROJECT_DIRECTORY
```

Replace the example repository URL and directory with your actual values.

### 2. Install dependencies

If the project includes a `package.json`, run:

```bash
npm install
```

### 3. Configure the environment

Set the environment variables supported by the application as needed:

| Variable | Purpose | Default / behavior |
| --- | --- | --- |
| `PORT` | Web panel listening port | `3000` |
| `SESSION_SECRET` | Secret used to sign sessions | A local secret is generated if this is not set |
| `SERVERS_DIR` | Optional server-files directory override | Defaults to `daemon/servers` relative to the application directory |

For production, set a strong, private `SESSION_SECRET` and keep environment files and secrets out of Git. Configure the remote node agent and its connectivity according to your deployment.

### 4. Start the panel

Use the start script defined in the project's `package.json`. If the project defines a `start` script, the usual command is:

```bash
npm start
```

If no start script is configured, check the project instructions and entry-point files before starting it directly.

### 5. Open the panel

When the application starts successfully, open the server address and port in your browser:

```text
http://YOUR_SERVER_IP:3000
```

If you configured a different `PORT`, use that port instead. For public deployment, configure HTTPS through a properly secured reverse proxy.

## 🔗 Remote Node Architecture

Atyro Panel's application code indicates a **remote-node-oriented architecture**. The web panel stores management data and communicates with remote node components for server operations.

Before using the panel to manage live servers:

1. Set up the required node agent using the matching project files and instructions.
2. Configure node connectivity and any required credentials.
3. Verify that the panel can communicate with the node.
4. Test server creation, start/stop actions, console output, and file operations with a disposable test server.
5. Confirm firewall rules and restrict node-management endpoints to trusted systems.

The panel alone may not be sufficient to run Minecraft servers if the remote node agent is missing or unconfigured.

## 🔒 Security Checklist

Before exposing Atyro Panel to the internet:

- [ ] Review the initial administrator-account creation logic in the application code. The current code includes a bootstrap account with username `admin` and password `admin123`; change or remove these defaults before deployment and never leave them active on a public server.
- [ ] Use unique, strong passwords for all accounts.
- [ ] Set a strong `SESSION_SECRET` and protect it from disclosure.
- [ ] Serve the panel over HTTPS.
- [ ] Keep Node.js and npm dependencies updated.
- [ ] Restrict remote-node access and management ports with a firewall.
- [ ] Protect database files, backups, logs, uploads, and environment secrets.
- [ ] Back up the SQLite database and server data before upgrades.
- [ ] Test permissions and administrative actions before inviting users.

## 🗂️ Data and Configuration

The application code defines an SQLite database at `database.db` in the application directory and writes application logs to `logs/latest.log`. The server-files directory defaults to `daemon/servers`, but it can be overridden with `SERVERS_DIR`.

Do not commit runtime databases, logs, uploaded files, credentials, session secrets, or private server data to a public repository.

## 🛠️ Troubleshooting

**The panel does not start**
- Confirm Node.js and npm are installed.
- Run `npm install` and check the terminal output for missing dependencies.
- Confirm the configured port is available.
- Review the application logs and terminal errors.

**Minecraft server actions do not work**
- Confirm the remote node agent is installed and running.
- Verify node configuration, network access, and firewall rules.
- Check the panel and node logs for connection or permission errors.

**Live console or statistics are unavailable**
- Confirm the browser can connect to the panel over Socket.IO.
- Check reverse-proxy WebSocket support and network/firewall rules.
- Confirm the remote node is reporting logs and statistics.

**Minecraft versions cannot be loaded**
- Check outbound network access and availability of the upstream software APIs.
- Review the application logs for request errors.

## 🗺️ Roadmap

Potential areas for future releases:

- Improved installation and node-setup documentation
- More detailed health checks for remote nodes
- Expanded monitoring and operational diagnostics
- Additional deployment and backup guidance

*Roadmap items are suggestions and are not promises of features in a particular release.*

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome. Before submitting a change:

1. Describe the problem or proposed improvement.
2. Test changes in a non-production environment.
3. Avoid including secrets, credentials, database files, or private server data.
4. Include clear reproduction steps for bug reports.

## 📜 License

No license was specified in the supplied application source. Until a license is added to the repository, do not assume that the project is open source or that redistribution and modification are permitted. Add a `LICENSE` file with the license chosen by Atyro Labs.

## 👨‍💻 Author

**Atyro Labs**  
**Project:** Atyro Panel  
**Release:** `v1.0.0`

---

<div align="center">

**Atyro Panel — Minecraft server management, organized.**

</div>
