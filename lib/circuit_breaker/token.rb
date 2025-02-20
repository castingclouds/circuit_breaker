module CircuitBreaker
  class Token
    attr_accessor :id, :title, :content, :author_id, :state
    attr_reader :data

    def initialize(data = {})
      @data = data
      @id = SecureRandom.uuid
      @title = data[:title]
      @content = data[:content]
      @author_id = data[:authorId]
      @state = data[:state] || 'draft'
    end

    def to_h
      {
        id: @id,
        title: @title,
        content: @content,
        authorId: @author_id,
        state: @state
      }
    end
  end
end
