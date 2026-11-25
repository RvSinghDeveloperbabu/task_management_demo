import { useCallback, useEffect, useState } from "react";
import { createTask, deleteTask, fetchInfo, fetchTasks } from "./api.js";

const POLL_MS = 2000;

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [info, setInfo] = useState(null);
  const [title, setTitle] = useState("");
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const [taskList, serverInfo] = await Promise.all([fetchTasks(), fetchInfo()]);
      setTasks(taskList);
      setInfo(serverInfo);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  // Poll so you can watch pending -> processing -> done as Sidekiq works.
  useEffect(() => {
    refresh();
    const timer = setInterval(refresh, POLL_MS);
    return () => clearInterval(timer);
  }, [refresh]);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!title.trim()) return;

    setSubmitting(true);
    try {
      await createTask(title.trim());
      setTitle("");
      await refresh();
    } catch (e) {
      setError(e.message);
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete(id) {
    try {
      await deleteTask(id);
      await refresh();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <main className="container">
      <h1>Task Queue Demo</h1>
      <p className="subtitle">React → Rails API → Sidekiq → Postgres / Redis</p>

      <section className="info">
        <div>
          <span className="label">API pod</span>
          <code>{info?.pod ?? "…"}</code>
        </div>
        <div>
          <span className="label">Sidekiq workers</span>
          <code>{info?.sidekiq?.processes ?? "?"}</code>
        </div>
        <div>
          <span className="label">Queued</span>
          <code>{info?.sidekiq?.enqueued ?? "?"}</code>
        </div>
        <div>
          <span className="label">Processed</span>
          <code>{info?.sidekiq?.processed ?? "?"}</code>
        </div>
      </section>

      <form onSubmit={handleSubmit} className="form">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="New task title"
          maxLength={200}
          aria-label="Task title"
        />
        <button type="submit" disabled={submitting || !title.trim()}>
          {submitting ? "Adding…" : "Add task"}
        </button>
      </form>

      {error && <p className="error">⚠ {error}</p>}

      <ul className="tasks">
        {tasks.map((task) => (
          <li key={task.id}>
            <div className="task-main">
              <strong>{task.title}</strong>
              {task.result && <small>{task.result}</small>}
            </div>
            <span className={`badge ${task.status}`}>{task.status}</span>
            <button className="delete" onClick={() => handleDelete(task.id)} aria-label="Delete task">
              ✕
            </button>
          </li>
        ))}
        {tasks.length === 0 && !error && <li className="empty">No tasks yet — add one above.</li>}
      </ul>
    </main>
  );
}
