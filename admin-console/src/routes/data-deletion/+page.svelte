<script lang="ts">
  export let data: {
    loadError: string | null;
    requests: Array<Record<string, any>>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;

  const statusOptions = ['pending', 'processing', 'completed', 'rejected'];

  function formatDate(dateStr: string) {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleString();
  }

  function statusBadgeClass(status: string) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return 'ok';
      case 'processing':
        return 'warn';
      case 'rejected':
        return 'err';
      default:
        return '';
    }
  }
</script>

<svelte:head>
  <title>Data Deletion — Amttai Admin</title>
</svelte:head>

<h1 class="page-title">Data Erasure Requests</h1>
<p class="page-subtitle">
  Review and manage user data deletion requests submitted through the legal portal.
</p>

{#if data.loadError}
  <p class="flash err">{data.loadError}</p>
{/if}

{#if form?.message}
  <p class="flash ok">{form.message}</p>
{/if}

{#if form?.error}
  <p class="flash err">{form.error}</p>
{/if}

<section class="card" style="margin-bottom: 16px;">
  <div style="display: flex; gap: 16px; flex-wrap: wrap;">
    <div>
      <strong style="font-size: 24px;">{data.requests.length}</strong>
      <p class="muted" style="margin: 0; font-size: 13px;">Total Requests</p>
    </div>
    <div>
      <strong style="font-size: 24px;">
        {data.requests.filter((r) => r.status === 'pending').length}
      </strong>
      <p class="muted" style="margin: 0; font-size: 13px;">Pending</p>
    </div>
    <div>
      <strong style="font-size: 24px;">
        {data.requests.filter((r) => r.status === 'processing').length}
      </strong>
      <p class="muted" style="margin: 0; font-size: 13px;">Processing</p>
    </div>
    <div>
      <strong style="font-size: 24px;">
        {data.requests.filter((r) => r.status === 'completed').length}
      </strong>
      <p class="muted" style="margin: 0; font-size: 13px;">Completed</p>
    </div>
    <div>
      <strong style="font-size: 24px;">
        {data.requests.filter((r) => r.status === 'rejected').length}
      </strong>
      <p class="muted" style="margin: 0; font-size: 13px;">Rejected</p>
    </div>
  </div>
</section>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>Email</th>
        <th>Full Name</th>
        <th>Status</th>
        <th>Confirmed</th>
        <th>Submitted</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each data.requests as req}
        <tr>
          <td>{req.email || '-'}</td>
          <td>{req.full_name || '-'}</td>
          <td>
            <span class="badge {statusBadgeClass(req.status)}">
              {req.status || 'pending'}
            </span>
          </td>
          <td>
            {#if req.confirmed}
              <span class="badge ok">Yes</span>
            {:else}
              <span class="badge">No</span>
            {/if}
          </td>
          <td>{formatDate(req.$createdAt)}</td>
          <td>
            <div class="actions">
              <form method="POST" action="?/updateStatus" style="display: flex; gap: 8px; align-items: center;">
                <input type="hidden" name="requestId" value={req.id} />
                <select name="status" style="width: 120px;">
                  {#each statusOptions as opt}
                    <option value={opt} selected={opt === (req.status || 'pending')}>
                      {opt}
                    </option>
                  {/each}
                </select>
                <button class="primary" type="submit">Update</button>
              </form>

              {#if req.status !== 'completed'}
                <form method="POST" action="?/processAndNotify">
                  <input type="hidden" name="requestId" value={req.id} />
                  <button class="danger" type="submit">Process & Notify</button>
                </form>
              {/if}

              <form method="POST" action="?/deleteRequest">
                <input type="hidden" name="requestId" value={req.id} />
                <button class="danger" type="submit">Delete</button>
              </form>
            </div>
          </td>
        </tr>
      {:else}
        <tr>
          <td colspan="6" style="text-align: center; color: #888;">No data erasure requests found.</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
