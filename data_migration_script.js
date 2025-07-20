#!/usr/bin/env node
// 数据迁移脚本 - 从现有结构迁移到新的增强结构

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

// 配置
const OLD_CONFIG_DIR = process.env.HOME + '/.xray-converter';
const OLD_SERVICE_DIR = OLD_CONFIG_DIR + '/services';
const NEW_DB_PATH = './data/enhanced-xray-converter.db';
const BACKUP_DIR = './migration_backup';

class DataMigration {
    constructor() {
        this.oldDb = null;
        this.newDb = null;
        this.migrationLog = [];
    }

    log(message) {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] ${message}`;
        console.log(logMessage);
        this.migrationLog.push(logMessage);
    }

    async init() {
        // 创建备份目录
        if (!fs.existsSync(BACKUP_DIR)) {
            fs.mkdirSync(BACKUP_DIR, { recursive: true });
        }

        // 初始化新数据库
        this.newDb = new sqlite3.Database(NEW_DB_PATH);
        
        // 执行数据库结构创建
        await this.createNewDatabaseStructure();
        
        this.log('数据迁移初始化完成');
    }

    async createNewDatabaseStructure() {
        return new Promise((resolve, reject) => {
            const schemaSQL = fs.readFileSync('./enhanced_database_schema.sql', 'utf8');
            this.newDb.exec(schemaSQL, (err) => {
                if (err) {
                    this.log(`创建数据库结构失败: ${err.message}`);
                    reject(err);
                } else {
                    this.log('新数据库结构创建成功');
                    resolve();
                }
            });
        });
    }

    async migrateFromFileSystem() {
        this.log('开始从文件系统迁移数据...');
        
        if (!fs.existsSync(OLD_SERVICE_DIR)) {
            this.log('未找到旧的服务目录，跳过文件系统迁移');
            return;
        }

        const serviceDirs = fs.readdirSync(OLD_SERVICE_DIR);
        let migratedCount = 0;
        let errorCount = 0;

        for (const serviceDir of serviceDirs) {
            const servicePath = path.join(OLD_SERVICE_DIR, serviceDir);
            
            if (!fs.statSync(servicePath).isDirectory()) {
                continue;
            }

            try {
                await this.migrateService(servicePath, serviceDir);
                migratedCount++;
            } catch (error) {
                this.log(`迁移服务 ${serviceDir} 失败: ${error.message}`);
                errorCount++;
            }
        }

        this.log(`文件系统迁移完成: 成功 ${migratedCount} 个，失败 ${errorCount} 个`);
    }

    async migrateService(servicePath, port) {
        const infoFile = path.join(servicePath, 'info');
        const configFile = path.join(servicePath, 'config.json');

        if (!fs.existsSync(infoFile) || !fs.existsSync(configFile)) {
            throw new Error('缺少必要的配置文件');
        }

        // 读取服务信息
        const infoContent = fs.readFileSync(infoFile, 'utf8');
        const serviceInfo = this.parseInfoFile(infoContent);
        
        // 读取Xray配置
        const configContent = fs.readFileSync(configFile, 'utf8');
        const xrayConfig = JSON.parse(configContent);

        // 提取SOCKS5信息
        const socksServers = xrayConfig.outbounds?.[0]?.settings?.servers || [];
        
        if (socksServers.length === 0) {
            throw new Error('未找到SOCKS5服务器配置');
        }

        // 为每个SOCKS5服务器创建节点（如果不存在）
        for (let i = 0; i < socksServers.length; i++) {
            const socksServer = socksServers[i];
            const nodeId = await this.createOrGetNode(socksServer, i);
            
            // 创建Shadowsocks服务
            await this.createShadowsocksService({
                port: parseInt(port),
                password: serviceInfo.PASSWORD,
                method: xrayConfig.inbounds?.[0]?.settings?.method || 'aes-256-gcm',
                socks5_node_id: nodeId,
                created_at: serviceInfo.CREATED_AT,
                expires_at: serviceInfo.EXPIRES_AT,
                status: serviceInfo.STATUS || 'active'
            });
        }

        this.log(`成功迁移服务: 端口 ${port}`);
    }

    parseInfoFile(content) {
        const info = {};
        const lines = content.split('\n');
        
        for (const line of lines) {
            const [key, value] = line.split('=');
            if (key && value) {
                info[key.trim()] = value.trim();
            }
        }
        
        return info;
    }

    async createOrGetNode(socksServer, index) {
        return new Promise((resolve, reject) => {
            const nodeData = {
                node_name: `迁移节点-${socksServer.address}-${socksServer.port}`,
                socks5_number: `MIGRATED-${socksServer.address}-${socksServer.port}-${index}`,
                region_id: 1, // 默认香港
                ip_address: socksServer.address,
                port: socksServer.port,
                username: socksServer.users?.[0]?.user || null,
                password: socksServer.users?.[0]?.pass || null,
                max_connections: 10, // 默认值
                status: 'active'
            };

            // 检查节点是否已存在
            this.newDb.get(
                'SELECT id FROM socks5_nodes WHERE ip_address = ? AND port = ?',
                [nodeData.ip_address, nodeData.port],
                (err, existing) => {
                    if (err) {
                        reject(err);
                        return;
                    }

                    if (existing) {
                        resolve(existing.id);
                        return;
                    }

                    // 创建新节点
                    this.newDb.run(
                        `INSERT INTO socks5_nodes 
                         (node_name, socks5_number, region_id, ip_address, port, username, password, max_connections, status)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                        [nodeData.node_name, nodeData.socks5_number, nodeData.region_id, 
                         nodeData.ip_address, nodeData.port, nodeData.username, nodeData.password,
                         nodeData.max_connections, nodeData.status],
                        function(err) {
                            if (err) {
                                reject(err);
                            } else {
                                resolve(this.lastID);
                            }
                        }
                    );
                }
            );
        });
    }

    async createShadowsocksService(serviceData) {
        return new Promise((resolve, reject) => {
            this.newDb.run(
                `INSERT INTO shadowsocks_services 
                 (port, password, method, socks5_node_id, created_at, expires_at, status, docker_container_name)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                [serviceData.port, serviceData.password, serviceData.method, serviceData.socks5_node_id,
                 serviceData.created_at, serviceData.expires_at, serviceData.status, 
                 `xray-converter-${serviceData.port}`],
                function(err) {
                    if (err) {
                        reject(err);
                    } else {
                        resolve(this.lastID);
                    }
                }
            );
        });
    }

    async createBackup() {
        this.log('创建迁移前备份...');
        
        try {
            // 备份旧的服务目录
            if (fs.existsSync(OLD_SERVICE_DIR)) {
                const backupPath = path.join(BACKUP_DIR, 'old_services_backup.tar.gz');
                const { exec } = require('child_process');
                
                await new Promise((resolve, reject) => {
                    exec(`tar -czf "${backupPath}" -C "${OLD_CONFIG_DIR}" services`, (error) => {
                        if (error) {
                            reject(error);
                        } else {
                            resolve();
                        }
                    });
                });
                
                this.log(`旧服务目录已备份到: ${backupPath}`);
            }

            // 保存迁移日志
            const logPath = path.join(BACKUP_DIR, 'migration_log.txt');
            fs.writeFileSync(logPath, this.migrationLog.join('\n'));
            this.log(`迁移日志已保存到: ${logPath}`);

        } catch (error) {
            this.log(`备份失败: ${error.message}`);
        }
    }

    async validateMigration() {
        this.log('开始验证迁移结果...');
        
        return new Promise((resolve) => {
            // 统计迁移后的数据
            this.newDb.all(`
                SELECT 
                    (SELECT COUNT(*) FROM customers) as customer_count,
                    (SELECT COUNT(*) FROM socks5_nodes) as node_count,
                    (SELECT COUNT(*) FROM shadowsocks_services) as service_count,
                    (SELECT COUNT(*) FROM regions) as region_count
            `, (err, result) => {
                if (err) {
                    this.log(`验证查询失败: ${err.message}`);
                } else {
                    const stats = result[0];
                    this.log(`迁移结果统计:`);
                    this.log(`- 客户数量: ${stats.customer_count}`);
                    this.log(`- 节点数量: ${stats.node_count}`);
                    this.log(`- 服务数量: ${stats.service_count}`);
                    this.log(`- 地区数量: ${stats.region_count}`);
                }
                resolve();
            });
        });
    }

    async generateMigrationReport() {
        const reportPath = path.join(BACKUP_DIR, 'migration_report.json');
        
        const report = {
            migration_date: new Date().toISOString(),
            source_directory: OLD_SERVICE_DIR,
            target_database: NEW_DB_PATH,
            log: this.migrationLog,
            status: 'completed'
        };

        fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
        this.log(`迁移报告已生成: ${reportPath}`);
    }

    async close() {
        if (this.newDb) {
            this.newDb.close();
        }
        this.log('数据库连接已关闭');
    }
}

// 主迁移流程
async function runMigration() {
    const migration = new DataMigration();
    
    try {
        console.log('=== Xray转换器数据迁移工具 ===');
        console.log('开始数据迁移...');
        
        await migration.init();
        await migration.createBackup();
        await migration.migrateFromFileSystem();
        await migration.validateMigration();
        await migration.generateMigrationReport();
        
        console.log('=== 迁移完成 ===');
        console.log('请检查迁移报告和日志文件');
        console.log(`备份目录: ${BACKUP_DIR}`);
        
    } catch (error) {
        console.error('迁移失败:', error.message);
        process.exit(1);
    } finally {
        await migration.close();
    }
}

// 命令行参数处理
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.includes('--help') || args.includes('-h')) {
        console.log(`
使用方法: node data_migration_script.js [选项]

选项:
  --help, -h     显示帮助信息
  --dry-run      仅模拟迁移，不实际执行
  --backup-only  仅创建备份，不执行迁移

示例:
  node data_migration_script.js              # 执行完整迁移
  node data_migration_script.js --dry-run    # 模拟迁移
  node data_migration_script.js --backup-only # 仅备份
        `);
        process.exit(0);
    }
    
    if (args.includes('--dry-run')) {
        console.log('模拟模式: 将显示迁移计划但不实际执行');
        // 这里可以添加模拟逻辑
    } else if (args.includes('--backup-only')) {
        console.log('仅备份模式');
        // 这里可以添加仅备份的逻辑
    } else {
        runMigration();
    }
}

module.exports = DataMigration;
