#!/bin/bash
# list-agents.sh - 列出所有注册的 Agent 及其状态
# 用法: bash ./skills/hrbp-list/scripts/list-agents.sh
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  echo "   Run ./scripts/dev.sh first to create the config."
  exit 1
fi

node -e "
  const fs = require('fs');
  const path = require('path');
  const c = JSON.parse(fs.readFileSync('$CONFIG_PATH','utf8'));
  const agents = c.agents?.list || [];
  const bindings = c.bindings || [];
  const mainAgent = agents.find(a => a.id === 'main');
  const allowAgents = mainAgent?.subagents?.allowAgents || [];

  if (agents.length === 0) {
    console.log('No agents configured.');
    process.exit(0);
  }

  console.log('');
  console.log('Registered Agents:');
  console.log('─'.repeat(90));
  console.log(
    'ID'.padEnd(20) +
    'Name'.padEnd(20) +
    'Route'.padEnd(12) +
    'Bindings'.padEnd(25) +
    'Workspace'
  );
  console.log('─'.repeat(90));

  for (const agent of agents) {
    const agentBindings = bindings.filter(b => b.agentId === agent.id);
    const hasBinding = agentBindings.length > 0;
    const isSpawnable = allowAgents.includes(agent.id) || agent.id === 'main';

    let route = '';
    if (agent.id === 'main') route = 'entry';
    else if (hasBinding && isSpawnable) route = 'both';
    else if (hasBinding) route = 'binding';
    else if (isSpawnable) route = 'spawn';
    else route = 'none';

    const bindStr = hasBinding
      ? agentBindings.map(b => b.match.channel + ':' + (b.match.accountId || '*')).join(', ')
      : '—';

    const ws = agent.workspace || '(default)';
    const wsExists = agent.workspace
      ? fs.existsSync(agent.workspace.replace('~', process.env.HOME))
      : true;

    console.log(
      agent.id.padEnd(20) +
      (agent.name || agent.id).padEnd(20) +
      route.padEnd(12) +
      bindStr.padEnd(25) +
      (wsExists ? '✅' : '❌') + ' ' + ws
    );
  }

  console.log('─'.repeat(90));
  console.log('Total: ' + agents.length + ' agent(s)');
  if (bindings.length > 0) {
    console.log('Bindings: ' + bindings.length + ' channel binding(s)');
  }
  console.log('');
"
