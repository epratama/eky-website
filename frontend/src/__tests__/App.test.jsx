import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import App from '../components/App'

describe('App', () => {
  it('renders without crashing', () => {
    render(<App />)
    expect(screen.getByText('Eky Pratama')).toBeInTheDocument()
  })

  it('renders all section IDs for navbar scrolling', () => {
    render(<App />)
    expect(document.getElementById('hero')).toBeInTheDocument()
    expect(document.getElementById('summary')).toBeInTheDocument()
    expect(document.getElementById('achievements')).toBeInTheDocument()
    expect(document.getElementById('experience')).toBeInTheDocument()
    expect(document.getElementById('skills')).toBeInTheDocument()
    expect(document.getElementById('education')).toBeInTheDocument()
    expect(document.getElementById('contact')).toBeInTheDocument()
  })

  it('renders the updated title', () => {
    render(<App />)
    const matches = screen.getAllByText('Technical Lead & Senior Software Engineer')
    expect(matches.length).toBeGreaterThanOrEqual(2)
  })
})
