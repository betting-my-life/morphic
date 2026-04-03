import { ProxyAgent, setGlobalDispatcher } from '/usr/local/lib/node_modules/undici/index.js';
if (process.env.HTTPS_PROXY) {
    setGlobalDispatcher(new ProxyAgent(process.env.HTTPS_PROXY));
}
