import SectionTitle from './SectionTitle'
import { useScrollReveal } from '../hooks/useScrollReveal'
import { GraduationCap, Award, ExternalLink } from 'lucide-react'

export default function Education({ education, certifications }) {
  const { ref, isVisible } = useScrollReveal()

  return (
    <section id="education" className="py-20 px-6">
      <div className="mx-auto max-w-4xl">
        <SectionTitle number="05" title="Education & Certifications" />

        <div
          ref={ref}
          className={`grid md:grid-cols-2 gap-6 transition-all duration-400 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
        >
          <div className="border-[3px] border-brutal-primary bg-white shadow-brutal p-6">
            <div className="flex items-center gap-2 mb-5">
              <GraduationCap size={20} className="text-brutal-accent" />
              <h3 className="font-heading text-sm font-extrabold text-brutal-accent uppercase tracking-wider">
                Education
              </h3>
            </div>

            <div className="space-y-5">
              {education.map((edu, i) => (
                <div key={i}>
                  <h4 className="font-heading text-base font-bold text-brutal-primary">
                    {edu.degree}
                  </h4>
                  <p className="font-body text-sm text-brutal-muted mt-0.5">
                    {edu.institution}
                  </p>
                  <span className="font-mono text-xs text-brutal-accent">
                    {edu.year}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className="border-[3px] border-brutal-primary bg-white shadow-brutal p-6">
            <div className="flex items-center gap-2 mb-5">
              <Award size={20} className="text-brutal-accent" />
              <h3 className="font-heading text-sm font-extrabold text-brutal-accent uppercase tracking-wider">
                Certifications
              </h3>
            </div>

            <div className="space-y-4">
              {certifications.map((cert, i) => (
                <div key={i}>
                  <h4 className="font-heading text-sm font-bold text-brutal-primary">
                    {cert.name}
                  </h4>
                  <p className="font-body text-xs text-brutal-muted mt-0.5">
                    {cert.issuer} — {cert.year}
                  </p>
                  {cert.url && cert.url.startsWith('https://') ? (
                    <a
                      href={cert.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 font-mono text-xs text-brutal-accent hover:text-brutal-primary mt-1 cursor-pointer transition-colors duration-150"
                    >
                      <ExternalLink size={12} />
                      View credential
                    </a>
                  ) : (
                    <span className="font-mono text-xs text-brutal-muted mt-1 block">
                      ID: {cert.id}
                    </span>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
