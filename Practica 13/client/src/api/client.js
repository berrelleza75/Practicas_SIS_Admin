import axios from 'axios';

const api = axios.create({ baseURL: '/api' });

export const getMachines = () => api.get('/machines').then(r => r.data);
export const updateMachine = (id, data) => api.put(`/machines/${id}`, data).then(r => r.data);

export const createUser = (data) => api.post('/users', data).then(r => r.data);

export const getServiceStatus = (service) => api.get(`/services/${service}/status`).then(r => r.data);
export const startService = (service) => api.post(`/services/${service}/start`).then(r => r.data);
export const stopService = (service) => api.post(`/services/${service}/stop`).then(r => r.data);

export const getDhcpLeases = () => api.get('/services/dhcp/leases').then(r => r.data);
export const getDnsZones = () => api.get('/services/dns/zones').then(r => r.data);
export const getDockerContainers = () => api.get('/services/docker/containers').then(r => r.data);
export const dockerAction = (action, container) => api.post(`/services/docker/${action}`, { container }).then(r => r.data);
export const getMailAccounts = () => api.get('/services/mail/accounts').then(r => r.data);
export const getSslCerts = () => api.get('/services/ssl/certs').then(r => r.data);
