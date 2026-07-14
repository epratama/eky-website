import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { readFileSync } from 'fs'
import { execSync } from 'child_process'
import { resolve } from 'path'
import App from '../components/App'

function getCspMetaContent() {
  const html = readFileSync(resolve(__dirname, '../../index.html'), 'utf-8')
  const match = html.match(/<meta[^>]*http-equiv="Content-Security-Policy"[^>]*content="([^"]*)"[^>]*>/)
  return match ? match[1] : ''
}

describe('App', () => {
  it('renders without crashing', () => {
    render(<App />)
    expect(screen.getByText('Eky Pratama')).toBeInTheDocument()
  })

  it('renders all section IDs for navbar scrolling', () => {
    render(<App />)
    expect(document.getElementById('home')).toBeInTheDocument()
    expect(document.getElementById('summary')).toBeInTheDocument()
    expect(document.getElementById('achievements')).toBeInTheDocument()
    expect(document.getElementById('experience')).toBeInTheDocument()
    expect(document.getElementById('skills')).toBeInTheDocument()
    expect(document.getElementById('education')).toBeInTheDocument()
    expect(document.getElementById('contact')).toBeInTheDocument()
    expect(document.getElementById('showcase')).toBeInTheDocument()
  })

  it('renders the updated title', () => {
    render(<App />)
    const matches = screen.getAllByText('Technical Lead & Senior Software Engineer')
    expect(matches.length).toBeGreaterThanOrEqual(2)
  })

  it('renders experience entries in descending chronological order', () => {
    render(<App />)
    const section = document.getElementById('experience')
    const html = section.innerHTML
    const swiftPos = html.indexOf('Swift Digital')
    const internetrixPos = html.indexOf('Internetrix')
    expect(swiftPos).toBeLessThan(internetrixPos)
  })

  it('renders GitHub links in Hero, Footer, and BuildShowcase', () => {
    render(<App />)
    const profileLinks = screen.getAllByRole('link', { name: 'GitHub' })
    expect(profileLinks).toHaveLength(2)
    profileLinks.forEach((link) => {
      expect(link).toHaveAttribute('href', 'https://github.com/epratama')
    })
    const repoLink = screen.getByRole('link', { name: /See the code/ })
    expect(repoLink).toHaveAttribute('href', 'https://github.com/epratama/eky-website')
  })

  it('renders the build showcase section with new copy', () => {
    render(<App />)
    expect(screen.getByText(/Multi-Agent AI/i)).toBeInTheDocument()
    expect(screen.getByText(/See how it's done/i)).toBeInTheDocument()
    expect(screen.getByText('See the code on GitHub →')).toBeInTheDocument()
  })

  it('renders BuildShowcase between Experience and Skills', () => {
    render(<App />)
    const sections = Array.from(document.querySelectorAll('section[id]'))
    const showcaseIdx = sections.findIndex(s => s.id === 'showcase')
    const experienceIdx = sections.findIndex(s => s.id === 'experience')
    const skillsIdx = sections.findIndex(s => s.id === 'skills')
    expect(showcaseIdx).toBeGreaterThan(experienceIdx)
    expect(showcaseIdx).toBeLessThan(skillsIdx)
  })

  it('renders ExperienceCard highlights button with bordered pill style', () => {
    render(<App />)
    const buttons = screen.getAllByRole('button', { name: /show highlights/i })
    expect(buttons.length).toBeGreaterThan(0)
    expect(buttons[0].className).toMatch(/border-\[3px\]/)
    expect(buttons[0].className).toMatch(/border-brutal-accent/)
  })

  it('CSP allows favicon data URI, hCaptcha, API Gateway, and Google Analytics connections', () => {
    const csp = getCspMetaContent()
    expect(csp).toContain("img-src 'self' data:")
    expect(csp).toContain('connect-src')
    expect(csp).toContain('*.hcaptcha.com')
    expect(csp).toContain('*.amazonaws.com')
    expect(csp).toContain('googletagmanager.com')
    expect(csp).toContain('google-analytics.com')
    expect(csp).toContain("frame-src")
    expect(csp).toContain("form-action 'self'")
  })

  it('includes GTM script in build when VITE_GTM_ID is set', () => {
    const tmpDir = resolve(__dirname, '../../dist-gtm-test')
    execSync(`VITE_GTM_ID=G-TEST123 npx vite build --outDir ${tmpDir}`, {
      cwd: resolve(__dirname, '../..'),
      stdio: 'pipe',
      env: { ...process.env, VITE_GTM_ID: 'G-TEST123' },
    })
    const html = readFileSync(resolve(tmpDir, 'index.html'), 'utf-8')
    expect(html).toContain('googletagmanager.com/gtag/js?id=G-TEST123')
    execSync(`rm -rf ${tmpDir}`)
  })
})
