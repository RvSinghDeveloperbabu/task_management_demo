// Relative URLs: works with the Vite proxy (dev) and the nginx proxy (Docker / Kubernetes).
async function request(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });

  if (response.status === 204) return null;

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(body.errors?.join(", ") || body.error || `Request failed (${response.status})`);
  }
  return body;
}

export const fetchTasks = () => request("/tasks");
export const fetchInfo = () => request("/info");
export const createTask = (title) =>
  request("/tasks", { method: "POST", body: JSON.stringify({ task: { title } }) });
export const deleteTask = (id) => request(`/tasks/${id}`, { method: "DELETE" });
