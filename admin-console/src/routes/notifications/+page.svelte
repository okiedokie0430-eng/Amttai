<script lang="ts">
  export let data: {
    loadError: string | null;
    recentMessages: Array<{
      id: string;
      status: string;
      createdAt: string;
      title: string;
      body: string;
      targetsTotal: number;
      deliveredTotal: number;
      failedTotal: number;
    }>;
  };

  export let form:
    | {
        message?: string;
        error?: string;
        input?: {
          title: string;
          body: string;
          action: string;
          data: string;
        };
        dispatch?: {
          id: string;
          status: string;
          createdAt: string;
          message: string;
          stats: {
            usersScanned: number;
            usersWithTargets: number;
            totalTargets: number;
            queuedMessages: number;
            queuedTargets: number;
            failedMessages: number;
            failedTargets: number;
            noTargetUsers: number;
            recipientMode: 'users' | 'targets';
            providerFilter: string | null;
            usedUserFallback: boolean;
          };
          messageIds: string[];
        };
      }
    | undefined;

  const defaultDataPayload = '{"screen":"home","source":"admin-console"}';

  $: titleValue = form?.input?.title ?? '';
  $: bodyValue = form?.input?.body ?? '';
  $: actionValue = form?.input?.action ?? '';
  $: dataValue = form?.input?.data ?? defaultDataPayload;
</script>

<svelte:head>
  <title>Notifications - Admin</title>
</svelte:head>

<h1 class="page-title">Notifications</h1>
<p class="muted" style="margin-top: -6px; margin-bottom: 16px;">
  Send a direct Appwrite Messaging push broadcast.
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

<section class="card" style="margin-bottom: 16px;">
  <h3 style="margin: 0 0 8px;">Send Broadcast</h3>
  <p class="muted" style="margin: 0 0 12px; font-size: 13px;">
    This now creates Appwrite push messages directly (same path as Messaging dashboard). Data JSON keys and values are flattened to strings for reliable delivery.
  </p>

  <form method="POST" action="?/sendBroadcast" class="form-grid">
    <div>
      <label for="title">Title</label>
      <input id="title" name="title" placeholder="Шинэ жор нэмэгдлээ" required value={titleValue} />
    </div>

    <div>
      <label for="body">Body</label>
      <input id="body" name="body" placeholder="Өнөөдрийн шинэ жорыг үзээрэй." required value={bodyValue} />
    </div>

    <div>
      <label for="action">Action URL (optional)</label>
      <input id="action" name="action" type="url" placeholder="amttai://recipe/123" value={actionValue} />
    </div>

    <div style="grid-column: 1 / -1;">
      <label for="data">Data JSON (optional)</label>
      <textarea
        id="data"
        name="data"
        rows="3"
        placeholder="&#123;&quot;screen&quot;:&quot;home&quot;,&quot;source&quot;:&quot;admin-console&quot;&#125;"
      >{dataValue}</textarea>
    </div>

    <div>
      <button class="primary" type="submit">Send Notification</button>
    </div>
  </form>
</section>

{#if form?.dispatch}
  <section class="card" style="margin-bottom: 16px;">
    <h3 style="margin: 0 0 10px;">Last Dispatch Result</h3>
    <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));">
      <div>
        <div class="muted" style="font-size: 13px;">Status</div>
        <div>{form.dispatch.status}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Created At</div>
        <div>{form.dispatch.createdAt}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Last Message ID</div>
        <div>{form.dispatch.id || '-'}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Created Messages</div>
        <div>{form.dispatch.messageIds.length}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Recipient Mode</div>
        <div>{form.dispatch.stats.recipientMode}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Provider Filter</div>
        <div>{form.dispatch.stats.providerFilter || '-'}</div>
      </div>
      <div>
        <div class="muted" style="font-size: 13px;">Fallback Used</div>
        <div>{form.dispatch.stats.usedUserFallback ? 'yes' : 'no'}</div>
      </div>
    </div>

    <div class="grid" style="margin-top: 12px;">
      <div class="card">
        <h3>Users Scanned</h3>
        <strong>{form.dispatch.stats.usersScanned}</strong>
      </div>
      <div class="card">
        <h3>Users With Targets</h3>
        <strong>{form.dispatch.stats.usersWithTargets}</strong>
      </div>
      <div class="card">
        <h3>Total Targets</h3>
        <strong>{form.dispatch.stats.totalTargets}</strong>
      </div>
      <div class="card">
        <h3>Queued Messages</h3>
        <strong>{form.dispatch.stats.queuedMessages}</strong>
      </div>
      <div class="card">
        <h3>Queued Targets</h3>
        <strong>{form.dispatch.stats.queuedTargets}</strong>
      </div>
      <div class="card">
        <h3>Failed Targets</h3>
        <strong>{form.dispatch.stats.failedTargets}</strong>
      </div>
    </div>
  </section>
{/if}

<section class="card">
  <h3 style="margin: 0 0 10px;">Recent Push Messages</h3>

  {#if data.recentMessages.length === 0}
    <p class="muted" style="margin: 0;">No push messages yet.</p>
  {:else}
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Time</th>
            <th>Status</th>
            <th>Title</th>
            <th>Targets</th>
            <th>Delivered</th>
            <th>Failed</th>
            <th>ID</th>
          </tr>
        </thead>
        <tbody>
          {#each data.recentMessages as message}
            <tr>
              <td>{message.createdAt}</td>
              <td>{message.status}</td>
              <td>{message.title || '-'}</td>
              <td>{message.targetsTotal}</td>
              <td>{message.deliveredTotal}</td>
              <td>{message.failedTotal}</td>
              <td>{message.id}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</section>
