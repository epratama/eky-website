import resume from '../data/resume.json'
import Navbar from './Navbar'
import Hero from './Hero'
import Summary from './Summary'
import KeyAchievements from './KeyAchievements'
import Experience from './Experience'
import Skills from './Skills'
import Education from './Education'
import ContactForm from './ContactForm'
import Footer from './Footer'

export default function App() {
  return (
    <div className="min-h-screen bg-brutal-bg text-brutal-text font-body">
      <Navbar />
      <Hero data={resume} />
      <Summary summary={resume.summary} />
      <KeyAchievements achievements={resume.keyAchievements} />
      <Experience experience={resume.experience} />
      <Skills skills={resume.skills} />
      <Education education={resume.education} certifications={resume.certifications} />
      <ContactForm />
      <Footer name={resume.name} role={resume.title} linkedin={resume.linkedin} github={resume.github} />
    </div>
  )
}
