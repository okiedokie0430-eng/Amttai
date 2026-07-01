<script lang="ts">
  import '../app.css';
  import { page } from '$app/stores';

  const links = [
    { href: '/', label: 'Dashboard' },
    { href: '/users', label: 'Users' },
    { href: '/recipes', label: 'Recipes' },
    { href: '/payments', label: 'Payments' },
    { href: '/notifications', label: 'Notifications' },
    { href: '/support', label: 'Support' },
    { href: '/data-deletion', label: 'Data Deletion' },
    { href: '/functions', label: 'Functions' }
  ];

  function isActive(href: string) {
    const path = $page.url.pathname;
    if (href === '/') return path === '/';
    return path === href || path.startsWith(href + '/');
  }
</script>

<div class="app-shell">
  <aside class="sidebar">
    <div class="sidebar-brand">Amttai</div>
    <nav class="sidebar-nav" aria-label="Primary">
      {#each links as link}
        <a href={link.href} class:active={isActive(link.href)}>
          {link.label}
        </a>
      {/each}
    </nav>
    <div class="sidebar-footer">
      <a href="/logout">Sign out</a>
    </div>
  </aside>

  <div class="main-area">
    <header class="topbar">
      <div class="topbar-title">Admin Console</div>
    </header>
    <main class="content">
      <slot />
    </main>
  </div>
</div>
