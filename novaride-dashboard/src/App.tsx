import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AppLayout } from './components/layout/AppLayout';
import { RequireAuth } from './components/layout/RequireAuth';
import { Login } from './pages/Login';
import { RiderDashboard } from './pages/RiderDashboard';
import { RiderMonitoring } from './pages/RiderMonitoring';
import { UserManagement } from './pages/UserManagement';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <RequireAuth>
              <AppLayout />
            </RequireAuth>
          }
        >
          <Route path="/" element={<RiderDashboard />} />
          <Route path="/monitoring" element={<RiderMonitoring />} />
          <Route path="/users" element={<UserManagement />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
