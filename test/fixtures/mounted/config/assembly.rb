Alki do
  mount :alki
  mount :piah do
    set(:processors) { assembly.processors }
  end
  auto_group :processors, '../processors', 'alki.build_service'
end
