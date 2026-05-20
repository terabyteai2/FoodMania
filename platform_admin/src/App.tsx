import { Navigate, Route, Routes } from "react-router-dom";
import { getToken } from "./api/client";
import LoginPage from "./auth/LoginPage";
import AdminLayout from "./layout/AdminLayout";
import DashboardPage from "./pages/DashboardPage";
import RestaurantsPage from "./pages/RestaurantsPage";
import OutletDetailPage from "./pages/OutletDetailPage";
import SubscriptionsPage from "./pages/SubscriptionsPage";
import PaymentsPage from "./pages/PaymentsPage";

function RequireAuth({ children }: { children: React.ReactNode }) {
  if (!getToken()) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <RequireAuth>
            <AdminLayout />
          </RequireAuth>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="restaurants" element={<RestaurantsPage />} />
        <Route path="outlets/:outletId" element={<OutletDetailPage />} />
        <Route path="subscriptions" element={<SubscriptionsPage />} />
        <Route path="payments" element={<PaymentsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
