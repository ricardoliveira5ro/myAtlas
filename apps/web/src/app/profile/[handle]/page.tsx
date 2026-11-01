type ProfilePageProps = {
  params: Promise<{ handle: string }>;
};

export default async function ProfilePage({ params }: ProfilePageProps) {
  const { handle } = await params;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-6 py-8 sm:px-10">
      <header className="flex items-center justify-between border-b border-emerald-950/10 pb-5">
        <a className="text-lg font-semibold tracking-tight text-[var(--accent)]" href="/">
          {process.env.NEXT_PUBLIC_SITE_NAME?.trim() || "My Atlas"}
        </a>
        <span className="text-sm text-[var(--muted)]">Public atlas</span>
      </header>
      <section className="flex flex-1 flex-col justify-center py-20">
        <p className="mb-4 text-sm font-semibold uppercase tracking-[0.18em] text-[var(--accent)]">
          Public profile
        </p>
        <h1 className="text-4xl font-semibold leading-tight tracking-tight sm:text-6xl">
          @{handle}
        </h1>
        <p className="mt-6 max-w-xl text-lg leading-8 text-[var(--muted)]">
          This is the beginning of {handle}&apos;s personal atlas.
        </p>
      </section>
      <footer className="border-t border-emerald-950/10 pt-5 text-sm text-[var(--muted)]">
        My Atlas · Places that matter
      </footer>
    </main>
  );
}
