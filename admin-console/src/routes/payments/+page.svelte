<script lang="ts">
  export let data: {
    loadError: string | null;
    payments: Array<Record<string, any>>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
      }
    | undefined;
</script>

<svelte:head>
  <title>Payments - Admin</title>
</svelte:head>

<h1 class="page-title">Payments</h1>
<p class="muted" style="margin-top: -6px; margin-bottom: 16px;">
  Approve or reject transactions and automatically sync premium access.
</p>

{#if data.loadError}
  <p class="badge err" style="margin-bottom: 12px;">{data.loadError}</p>
{/if}

{#if form?.message}
  <p class="badge ok" style="margin-bottom: 12px;">{form.message}</p>
{/if}

{#if form?.error}
  <p class="badge err" style="margin-bottom: 12px;">{form.error}</p>
{/if}

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>User ID</th>
        <th>Plan</th>
        <th>Amount</th>
        <th>Code</th>
        <th>Status</th>
        <th>Created</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {#each data.payments as payment}
        <tr>
          <td>{payment.user_id}</td>
          <td>{payment.plan}</td>
          <td>{payment.amount}</td>
          <td>{payment.transaction_code}</td>
          <td>
            {#if payment.status === 'approved'}
              <span class="badge ok">Approved</span>
            {:else if payment.status === 'rejected'}
              <span class="badge err">Rejected</span>
            {:else}
              <span class="badge warn">Pending</span>
            {/if}
          </td>
          <td>{payment.created_at}</td>
          <td>
            <div class="actions">
              <form method="POST" action="?/approve">
                <input type="hidden" name="paymentId" value={payment.id} />
                <button class="success" type="submit">Approve</button>
              </form>
              <form method="POST" action="?/reject">
                <input type="hidden" name="paymentId" value={payment.id} />
                <button class="danger" type="submit">Reject</button>
              </form>
            </div>
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
