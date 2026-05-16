import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Machines from './pages/Machines';
import Users from './pages/Users';
import SSH from './pages/services/SSH';
import DHCP from './pages/services/DHCP';
import DNS from './pages/services/DNS';
import FTP from './pages/services/FTP';
import SSL from './pages/services/SSL';
import Docker from './pages/services/Docker';
import Mail from './pages/services/Mail';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/"                  element={<Dashboard />} />
          <Route path="/machines"          element={<Machines />} />
          <Route path="/users"             element={<Users />} />
          <Route path="/services/ssh"      element={<SSH />} />
          <Route path="/services/dhcp"     element={<DHCP />} />
          <Route path="/services/dns"      element={<DNS />} />
          <Route path="/services/ftp"      element={<FTP />} />
          <Route path="/services/ssl"      element={<SSL />} />
          <Route path="/services/docker"   element={<Docker />} />
          <Route path="/services/mail"     element={<Mail />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
