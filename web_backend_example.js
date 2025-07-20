// Web端后端实现示例 - Node.js + Express
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { exec } = require('child_process');
const Docker = require('dockerode');
const sqlite3 = require('sqlite3').verbose();
const WebSocket = require('ws');
const path = require('path');

const app = express();
const docker = new Docker();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// 中间件
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// 数据库初始化
const db = new sqlite3.Database('./data/xray-converter.db');

// 初始化数据库表
db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        port INTEGER UNIQUE NOT NULL,
        password TEXT NOT NULL,
        method TEXT DEFAULT 'aes-256-gcm',
        socks_servers TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        expires_at INTEGER,
        remark TEXT,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT DEFAULT 'user',
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS operation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        target TEXT,
        details TEXT,
        ip_address TEXT,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
    )`);
});

// JWT 验证中间件
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: '访问令牌缺失' });
    }
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: '访问令牌无效' });
        }
        req.user = user;
        next();
    });
};

// 操作日志记录
const logOperation = (userId, action, target, details, ipAddress) => {
    db.run(
        'INSERT INTO operation_logs (user_id, action, target, details, ip_address) VALUES (?, ?, ?, ?, ?)',
        [userId, action, target, JSON.stringify(details), ipAddress]
    );
};

// 认证路由
app.post('/api/auth/login', async (req, res) => {
    const { username, password } = req.body;
    
    db.get('SELECT * FROM users WHERE username = ?', [username], async (err, user) => {
        if (err) {
            return res.status(500).json({ error: '数据库错误' });
        }
        
        if (!user || !await bcrypt.compare(password, user.password_hash)) {
            return res.status(401).json({ error: '用户名或密码错误' });
        }
        
        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        logOperation(user.id, 'login', 'system', {}, req.ip);
        
        res.json({
            token,
            user: {
                id: user.id,
                username: user.username,
                role: user.role
            }
        });
    });
});

// 服务管理路由
app.get('/api/services', authenticateToken, (req, res) => {
    const { page = 1, limit = 10, status, search } = req.query;
    const offset = (page - 1) * limit;
    
    let query = 'SELECT * FROM services';
    let countQuery = 'SELECT COUNT(*) as total FROM services';
    const params = [];
    const conditions = [];
    
    if (status) {
        conditions.push('status = ?');
        params.push(status);
    }
    
    if (search) {
        conditions.push('(port LIKE ? OR remark LIKE ?)');
        params.push(`%${search}%`, `%${search}%`);
    }
    
    if (conditions.length > 0) {
        const whereClause = ' WHERE ' + conditions.join(' AND ');
        query += whereClause;
        countQuery += whereClause;
    }
    
    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), offset);
    
    // 获取总数
    db.get(countQuery, params.slice(0, -2), (err, countResult) => {
        if (err) {
            return res.status(500).json({ error: '数据库错误' });
        }
        
        // 获取服务列表
        db.all(query, params, async (err, services) => {
            if (err) {
                return res.status(500).json({ error: '数据库错误' });
            }
            
            // 获取实时状态
            const servicesWithStatus = await Promise.all(
                services.map(async (service) => {
                    const containerStatus = await getContainerStatus(service.port);
                    return {
                        ...service,
                        runtime_status: containerStatus,
                        socks_servers: JSON.parse(service.socks_servers)
                    };
                })
            );
            
            res.json({
                services: servicesWithStatus,
                total: countResult.total,
                page: parseInt(page),
                limit: parseInt(limit)
            });
        });
    });
});

app.post('/api/services', authenticateToken, async (req, res) => {
    const { port, password, socksServers, expiresAt, remark } = req.body;
    
    // 验证输入
    if (!port || !password || !socksServers || !Array.isArray(socksServers)) {
        return res.status(400).json({ error: '参数不完整' });
    }
    
    if (port < 1 || port > 65535) {
        return res.status(400).json({ error: '端口号无效' });
    }
    
    try {
        // 检查端口是否已被使用
        db.get('SELECT id FROM services WHERE port = ?', [port], async (err, existing) => {
            if (err) {
                return res.status(500).json({ error: '数据库错误' });
            }
            
            if (existing) {
                return res.status(400).json({ error: '端口已被使用' });
            }
            
            // 创建服务配置
            const config = {
                inbounds: [{
                    port: port,
                    protocol: 'shadowsocks',
                    settings: {
                        method: 'aes-256-gcm',
                        password: password,
                        network: 'tcp,udp'
                    },
                    tag: 'ss-in'
                }],
                outbounds: [{
                    protocol: 'socks',
                    settings: {
                        servers: socksServers
                    },
                    tag: 'socks-out'
                }],
                routing: {
                    rules: [{
                        type: 'field',
                        inboundTag: ['ss-in'],
                        outboundTag: 'socks-out'
                    }]
                }
            };
            
            // 启动Docker容器
            const containerName = `xray-converter-${port}`;
            
            try {
                const container = await docker.createContainer({
                    Image: 'teddysun/xray',
                    name: containerName,
                    ExposedPorts: {
                        [`${port}/tcp`]: {},
                        [`${port}/udp`]: {}
                    },
                    HostConfig: {
                        PortBindings: {
                            [`${port}/tcp`]: [{ HostPort: port.toString() }],
                            [`${port}/udp`]: [{ HostPort: port.toString() }]
                        },
                        RestartPolicy: {
                            Name: 'unless-stopped'
                        }
                    },
                    Env: [`XRAY_CONFIG=${JSON.stringify(config)}`]
                });
                
                await container.start();
                
                // 保存到数据库
                db.run(
                    'INSERT INTO services (port, password, socks_servers, expires_at, remark) VALUES (?, ?, ?, ?, ?)',
                    [port, password, JSON.stringify(socksServers), expiresAt, remark],
                    function(err) {
                        if (err) {
                            return res.status(500).json({ error: '数据库保存失败' });
                        }
                        
                        logOperation(req.user.id, 'create_service', `port:${port}`, { port, remark }, req.ip);
                        
                        res.status(201).json({
                            id: this.lastID,
                            port,
                            password,
                            status: 'active',
                            message: '服务创建成功'
                        });
                    }
                );
                
            } catch (dockerErr) {
                console.error('Docker error:', dockerErr);
                res.status(500).json({ error: 'Docker容器创建失败' });
            }
        });
        
    } catch (error) {
        console.error('Service creation error:', error);
        res.status(500).json({ error: '服务创建失败' });
    }
});

app.delete('/api/services/:id', authenticateToken, async (req, res) => {
    const serviceId = req.params.id;
    
    db.get('SELECT * FROM services WHERE id = ?', [serviceId], async (err, service) => {
        if (err) {
            return res.status(500).json({ error: '数据库错误' });
        }
        
        if (!service) {
            return res.status(404).json({ error: '服务不存在' });
        }
        
        try {
            // 停止并删除Docker容器
            const containerName = `xray-converter-${service.port}`;
            const container = docker.getContainer(containerName);
            
            try {
                await container.stop();
                await container.remove();
            } catch (dockerErr) {
                console.log('Container not found or already stopped');
            }
            
            // 从数据库删除
            db.run('DELETE FROM services WHERE id = ?', [serviceId], (err) => {
                if (err) {
                    return res.status(500).json({ error: '数据库删除失败' });
                }
                
                logOperation(req.user.id, 'delete_service', `port:${service.port}`, { port: service.port }, req.ip);
                
                res.json({ message: '服务删除成功' });
            });
            
        } catch (error) {
            console.error('Service deletion error:', error);
            res.status(500).json({ error: '服务删除失败' });
        }
    });
});

// 获取容器状态
async function getContainerStatus(port) {
    try {
        const containerName = `xray-converter-${port}`;
        const container = docker.getContainer(containerName);
        const info = await container.inspect();
        return info.State.Status;
    } catch (error) {
        return 'missing';
    }
}

// 系统状态路由
app.get('/api/system/status', authenticateToken, async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const xrayContainers = containers.filter(c => 
            c.Names.some(name => name.includes('xray-converter'))
        );
        
        const stats = {
            total_services: 0,
            running_services: 0,
            stopped_services: 0,
            docker_status: 'running'
        };
        
        db.get('SELECT COUNT(*) as total FROM services', (err, result) => {
            if (!err) {
                stats.total_services = result.total;
            }
            
            stats.running_services = xrayContainers.filter(c => c.State === 'running').length;
            stats.stopped_services = xrayContainers.filter(c => c.State !== 'running').length;
            
            res.json(stats);
        });
        
    } catch (error) {
        res.status(500).json({ error: '获取系统状态失败' });
    }
});

// WebSocket 服务器
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
    console.log('WebSocket client connected');
    
    // 发送实时日志
    const logInterval = setInterval(() => {
        // 这里可以实现实时日志推送
        ws.send(JSON.stringify({
            type: 'log',
            data: {
                timestamp: Date.now(),
                level: 'info',
                message: 'System running normally'
            }
        }));
    }, 5000);
    
    ws.on('close', () => {
        clearInterval(logInterval);
        console.log('WebSocket client disconnected');
    });
});

// 启动服务器
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
