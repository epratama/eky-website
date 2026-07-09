import { useState, useEffect } from 'react'

const SECTIONS = [
  { id: 'home', label: 'Home' },
  { id: 'summary', label: 'About' },
  { id: 'achievements', label: 'Achievements' },
  { id: 'experience', label: 'Experience' },
  { id: 'skills', label: 'Skills' },
  { id: 'education', label: 'Education' },
  { id: 'contact', label: 'Contact' },
]

export default function Navbar() {
  const [activeSection, setActiveSection] = useState('hero')
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const observers = []
    SECTIONS.forEach(({ id }) => {
      const el = document.getElementById(id)
      if (!el) return
      const observer = new IntersectionObserver(
        ([entry]) => {
          if (entry.isIntersecting) setActiveSection(id)
        },
        { threshold: 0.3, rootMargin: '-80px 0px 0px 0px' }
      )
      observer.observe(el)
      observers.push(observer)
    })
    return () => observers.forEach((o) => o.disconnect())
  }, [])

  return (
    <nav className="fixed top-3 left-3 right-3 z-50">
      <div className="mx-auto max-w-3xl border-[3px] border-brutal-primary bg-brutal-bg shadow-brutal">
        <div className="flex items-center justify-between px-4 py-2">
          <a
            href="#home"
            className="font-heading text-lg font-extrabold text-brutal-primary hover:text-brutal-accent cursor-pointer"
          >
            EP
          </a>

          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="sm:hidden font-body font-bold text-sm text-brutal-primary cursor-pointer"
            aria-expanded={menuOpen}
            aria-controls="mobile-menu"
            aria-label="Toggle navigation"
          >
            {menuOpen ? 'CLOSE' : 'MENU'}
          </button>

          <div className="hidden sm:flex gap-1">
            {SECTIONS.map(({ id, label }) => (
              <a
                key={id}
                href={`#${id}`}
                className={`px-3 py-1.5 font-body text-sm font-semibold cursor-pointer border-[2px] ${
                  activeSection === id
                    ? 'bg-brutal-primary text-brutal-bg border-brutal-primary'
                    : 'text-brutal-primary border-transparent hover:border-brutal-primary'
                }`}
              >
                {label}
              </a>
            ))}
          </div>
        </div>

        {menuOpen && (
          <div id="mobile-menu" className="sm:hidden border-t-[3px] border-brutal-primary flex flex-col">
            {SECTIONS.map(({ id, label }) => (
              <a
                key={id}
                href={`#${id}`}
                onClick={() => setMenuOpen(false)}
                className={`px-4 py-2.5 font-body text-sm font-semibold cursor-pointer ${
                  activeSection === id
                    ? 'bg-brutal-primary text-brutal-bg'
                    : 'text-brutal-primary hover:bg-brutal-primary hover:text-brutal-bg'
                }`}
              >
                {label}
              </a>
            ))}
          </div>
        )}
      </div>
    </nav>
  )
}
