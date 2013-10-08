swap_file '/var/swapfile' do
  size    node.swapfile
  persist true
end
