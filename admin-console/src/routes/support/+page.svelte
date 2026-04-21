<script lang="ts">
  export let data: {
    loadError: string | null;
    messages: Array<Record<string, any>>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;
</script>

<svelte:head>
  <title>Support - Admin</title>
</svelte:head>

<h1 class="page-title">Support Messages</h1>

{#if data.loadError}
  <p class="badge err" style="margin-bottom: 12px;">{data.loadError}</p>
{/if}

{#if form?.message}
  <p class="badge ok" style="margin-bottom: 12px;">{form.message}</p>
{/if}

{#if form?.error}
  <p class="badge err" style="margin-bottom: 12px;">{form.error}</p>
{/if}

<section class="card" style="margin-bottom: 16px;">
  <h3 style="margin: 0 0 10px;">Reply to User</h3>
  <form method="POST" action="?/reply" class="form-grid">
    <div>
      <label for="userId">User ID</label>
      <input id="userId" name="userId" required />
    </div>
    <div style="grid-column: 1 / -1;">
      <label for="message">Message</label>
      <textarea id="message" name="message" rows="3" required></textarea>
    </div>
    <div>
      <button class="primary" type="submit">Send Reply</button>
    </div>
  </form>
</section>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>User ID</th>
        <th>Message</th>
        <th>From Admin</th>
        <th>Created</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each data.messages as message}
        <tr>
          <td>{message.user_id}</td>
          <td>{message.message}</td>
          <td>{message.is_from_admin ? 'Yes' : 'No'}</td>
          <td>{message.created_at}</td>
          <td>
            <form method="POST" action="?/deleteMessage">
              <input type="hidden" name="messageId" value={message.id} />
              <button class="danger" type="submit">Delete</button>
            </form>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
