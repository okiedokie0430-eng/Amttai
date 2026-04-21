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
    { href: '/functions', label: 'Functions' }
  ];
</script>

<div class="app-shell">
  <header class="topbar">
    <div class="brand">Amttai Admin Console</div>
    <nav class="nav" aria-label="Primary">
      {#each links as link}
        <a href={link.href} class:active={$page.url.pathname === link.href}>{link.label}</a>
      {/each}
    </nav>
    <a class="button" href="/logout">Sign out</a>
  </header>

  <main class="content">
    <slot />
  </main>
</div>

<style>
  a.active {
    font-weight: 700;
  }
</style>
