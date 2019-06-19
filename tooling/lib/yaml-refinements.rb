# Psych::Nodes::Mappings doesn't have good indexing operators; patch them in
module YAMLRefine
    refine Psych::Nodes::Mapping do
        def [](key)
            children.each_slice(2) do |k, v|
                return v if k.value == key
            end
            nil
        end
        def []=(key, value)
            value_node = Psych::Visitors::YAMLTree.create.push(value).first
            children.each_slice(2).each_with_index do |(k, v), index|
                if k.value == key
                    children[index * 2 + 1] = value_node
                    return
                end
            end
            key_node = Psych::Visitors::YAMLTree.create.push(key).first
            children << key_node << value_node
        end
    end
end
