import { Linkedin, Github, ArrowUp } from 'lucide-react'

export default function Footer({ name, role, linkedin, github }) {
  return (
    <footer className="border-t-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg py-10 px-6">
      <div className="mx-auto max-w-6xl flex flex-col sm:flex-row items-center justify-between gap-6">
        <div className="text-center sm:text-left">
          <p className="font-heading text-lg font-extrabold">{name}</p>
          <p className="font-body text-sm text-[#A1A1AA] mt-1">
            {role}
          </p>
          <div className="flex items-center justify-center sm:justify-start gap-4 mt-3">
            <a
              href={linkedin}
              target="_blank"
              rel="noopener noreferrer"
              className="text-brutal-bg hover:text-brutal-accent transition-colors duration-150 cursor-pointer"
              aria-label="LinkedIn"
            >
              <Linkedin size={20} />
            </a>
            <a
              href={github}
              target="_blank"
              rel="noopener noreferrer"
              className="text-brutal-bg hover:text-brutal-accent transition-colors duration-150 cursor-pointer"
              aria-label="GitHub"
            >
              <Github size={20} />
            </a>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <a
            href="#home"
            className="flex items-center gap-2 border-[2px] border-brutal-bg px-4 py-2 font-body text-sm font-bold text-brutal-bg hover:bg-brutal-bg hover:text-brutal-primary cursor-pointer transition-colors duration-150"
            aria-label="Back to top"
          >
            <ArrowUp size={16} />
            Top
          </a>
        </div>
      </div>

      <p className="font-mono text-xs text-center mt-8 text-[#A1A1AA]">
        &copy; {new Date().getFullYear()} {name}
      </p>
    </footer>
  )
}
