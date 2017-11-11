Alki do
  input :as
  input :bs

  process do
    as.each do |a|
      output items: ["a#{a}"]
    end

    bs.each do |b|
      output items: ["b#{b}"]
    end
  end
end
