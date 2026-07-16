import { createRoot } from "react-dom/client";
import OffshiftWidget from "./OffshiftWidget";

const root = document.getElementById("offshift-root");

if (root) {
  createRoot(root).render(<OffshiftWidget />);
}

export { OffshiftWidget as App };
export default OffshiftWidget;
