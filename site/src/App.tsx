import LetterGlitch from "@/components/LetterGlitch"
import FuzzyText from "@/components/FuzzyText"
import RotatingText from "@/components/RotatingText"
import { Marquee } from "@/components/ui/marquee"
import { Meteors } from "@/components/ui/meteors"
import { ContainerScroll } from "@/components/ui/container-scroll-animation"
import { SparklesCore } from "@/components/ui/sparkles"
import Footer from "@/components/monet/Footer"

const REPO = "https://github.com/ethembeldagli/roastfetch"
const INSTALL = "curl -fsSL https://raw.githubusercontent.com/ethembeldagli/roastfetch/main/install.sh | sh"
const FIRE = "#ff4d1a"

const ROASTS: [string, string][] = [
  ["I use Arch btw. Yes, we know. You've mentioned it.", "to every Arch user"],
  ["It's 2 AM and you're running roastfetch. Go to sleep.", "to night owls"],
  ["Disk 96% full. One more game update and it's over.", "to the hoarders"],
  ["Hybrid graphics: one GPU works, the other one judges you.", "to laptop gamers"],
  ["Ubuntu: the distro your distro-hopping started from.", "to Ubuntu users"],
  ["402h in Elden Ring. Touching grass is free, you know.", "to Steam libraries"],
  ["Uptime 39 days. Your kernel updates are begging.", "to the never-rebooters"],
  ["Hyprland on a laptop with 4 GB of RAM. Brave.", "to ricers"],
]

const Quote = ([q, who]: [string, string]) => (
  <figure key={q} className="w-80 border-l-4 pl-4" style={{ borderColor: FIRE }}>
    <blockquote className="text-xl italic leading-snug">“{q}”</blockquote>
    <figcaption className="mono mt-2 text-xs uppercase tracking-widest text-black/50">— roastfetch, {who}</figcaption>
  </figure>
)

export default function App() {
  return (
    <div className="mx-auto max-w-[1400px] px-4 md:px-8">
      {/* masthead */}
      <header className="mono flex flex-wrap items-center justify-between gap-2 border-b-2 rule py-3 text-[11px] uppercase tracking-[0.2em]">
        <span>Vol. 0.2.0</span>
        <span className="display text-base tracking-[0.3em]">The Daily Roast</span>
        <span>Free · MIT · Any distro</span>
      </header>

      {/* front page */}
      <section className="grid gap-8 border-b-2 rule py-10 lg:grid-cols-[1.4fr_1fr]">
        <div>
          <p className="mono text-xs uppercase tracking-[0.3em] text-black/60">Breaking · Your terminal has opinions now</p>
          <div className="-ml-2 mt-4 overflow-hidden">
            <FuzzyText fontSize="clamp(4.5rem, 14vw, 12rem)" fontFamily="Anton" color="#12100c" baseIntensity={0.08} hoverIntensity={0.5} enableHover>roastfetch</FuzzyText>
          </div>
          <h1 className="mt-4 max-w-2xl text-4xl font-semibold leading-tight md:text-5xl">
            Your fetch, same logo, same info. Then it{" "}
            <RotatingText texts={["roasts your distro.", "judges your editor.", "counts your Steam hours.", "notices it's 3 AM."]} rotationInterval={2600}
              highlight highlightColor={FIRE} mainClassName="px-2 text-white" staggerDuration={0.02} />
          </h1>
          <div className="mt-8 grid gap-6 border-t rule pt-6 md:grid-cols-2">
            <p className="dropcap text-lg leading-relaxed">roastfetch runs the fastfetch or neofetch you already use, exactly as your shell would, so you get your own distro logo and every line you're used to. Underneath, it adds a few lines about your setup that nobody asked for.</p>
            <p className="text-lg leading-relaxed">It reads your distro, desktop, terminal, editor, GPU, packages, uptime, disk and Steam playtime, all on your machine. It starts in under 100 ms, so it's fine in your shell's startup file. The roasts are about your setup, never about you.</p>
          </div>
        </div>
        <figure>
          <div className="relative aspect-[4/5] overflow-hidden border-2 rule bg-black">
            <LetterGlitch glitchColors={["#ff4d1a", "#ffb000", "#5a1a06"]} backgroundColor="#0d0b08" speed={1.2} centerFade={0.4} smooth className="h-full w-full" />
            <div className="pointer-events-none absolute inset-x-0 bottom-0 p-4">
              <span className="display text-6xl leading-none text-white mix-blend-screen md:text-7xl">4/10</span>
              <p className="mono text-xs text-white/70">Doneness: medium rare</p>
            </div>
          </div>
          <figcaption className="mono mt-2 text-[11px] uppercase tracking-widest text-black/60">Fig. 1 — your terminal, moments before</figcaption>
        </figure>
      </section>

      {/* letters to the editor */}
      <section className="border-b-2 rule py-10">
        <h2 className="display mb-6 text-5xl md:text-7xl">Overheard in terminals</h2>
        <Marquee pauseOnHover className="[--duration:45s] [--gap:3rem]">{ROASTS.slice(0, 4).map(Quote)}</Marquee>
        <Marquee pauseOnHover reverse className="mt-6 [--duration:50s] [--gap:3rem]">{ROASTS.slice(4).map(Quote)}</Marquee>
      </section>

      {/* the photo spread */}
      <section className="-mx-4 border-b-2 rule md:-mx-8">
        <ContainerScroll titleComponent={
          <h2 className="display text-5xl leading-none md:text-8xl">Same fetch.<br /><span style={{ color: FIRE }}>New opinions.</span></h2>
        }>
          <img src="./screenshot.png" alt="roastfetch output: an Arch Linux logo, system info and five roasts with a doneness score" className="mx-auto h-full w-full rounded-xl object-contain bg-[#14161c]" />
        </ContainerScroll>
      </section>

      {/* classifieds */}
      <section className="grid gap-0 border-b-2 rule md:grid-cols-3">
        {[
          ["Exactly your fetch", "Runs fastfetch or neofetch with your own aliases and config. If you have neither, it draws the logo itself."],
          ["Any distro", "Arch, Fedora, Ubuntu, Debian, openSUSE, Alpine, NixOS, Bazzite and the rest. Python 3.9+, no dependencies."],
          ["Write a roast", "Every roast is one line of Python. Add one for your distro and open a pull request."],
        ].map(([t, d], i) => (
          <article key={t} className={`p-6 ${i ? "md:border-l-2 rule" : ""} border-t-2 md:border-t-0 first:border-t-0`}>
            <p className="mono text-xs uppercase tracking-widest" style={{ color: FIRE }}>No. {i + 1}</p>
            <h3 className="display mt-2 text-3xl">{t}</h3>
            <p className="mt-2 text-lg leading-relaxed">{d}</p>
          </article>
        ))}
      </section>

      {/* the oven */}
      <section id="install" className="relative my-10 overflow-hidden bg-[#0d0b08] px-6 py-20 text-center text-white">
        <div className="absolute inset-0"><SparklesCore background="transparent" particleColor={FIRE} particleDensity={60} minSize={0.6} maxSize={1.6} speed={2} className="h-full w-full" /></div>
        <Meteors number={24} />
        <div className="relative">
          <p className="mono text-xs uppercase tracking-[0.3em] text-white/60">Get roasted</p>
          <h2 className="display mt-3 text-6xl md:text-8xl">One line. Medium rare.</h2>
          <button onClick={() => navigator.clipboard?.writeText(INSTALL)} className="mono mx-auto mt-8 block max-w-3xl break-all border border-white/20 bg-black/60 px-5 py-4 text-left text-sm hover:border-white/50">
            <span style={{ color: FIRE }}>$</span> {INSTALL} <span className="text-white/40">· click to copy</span>
          </button>
          <p className="mono mt-4 text-xs text-white/50">Run it again to update or uninstall · then just type <span className="text-white">roastfetch</span></p>
          <a href={REPO} className="mono mt-6 inline-block text-sm underline underline-offset-4">github.com/ethembeldagli/roastfetch →</a>
        </div>
      </section>

      <div className="-mx-4 md:-mx-8"><Footer mode="dark" /></div>
    </div>
  )
}
