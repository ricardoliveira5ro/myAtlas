export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-6 py-8 sm:px-10">
      <header className="flex items-center justify-between border-b border-emerald-950/10 pb-5">
        <a className="text-lg font-semibold tracking-tight text-[var(--accent)]" href="/">
          {process.env.NEXT_PUBLIC_SITE_NAME?.trim() || "My Atlas"}
        </a>
        <span className="text-sm text-[var(--muted)]">Your places, your story</span>
      </header>
      <section className="flex flex-1 flex-col justify-center py-20">
        <p className="mb-4 text-sm font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">
          A place to begin
        </p>
        <h1 className="max-w-2xl text-4xl font-semibold leading-tight tracking-tight sm:text-6xl">
          Keep the places that make a life.
        </h1>
        <p className="mt-6 max-w-xl text-lg leading-8 text-[var(--muted)]">
          Your personal atlas is taking shape. This simple web shell is the starting point for
          collecting and sharing meaningful places.
        </p>
      </section>
      <footer className="border-t border-emerald-950/10 pt-5 text-sm text-[var(--muted)]">
        My Atlas · The beginning of your map
      </footer>
    </main>
  );
}
