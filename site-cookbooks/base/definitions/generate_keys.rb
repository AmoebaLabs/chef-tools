define :generate_keys, user: nil, home: nil do
  user_name   = params[:user]   || params[:name]
  user_home   = params[:home]   || "/home/#{user_name}"

  ssh_dir = "#{user_home}/.ssh"

  execute "generate ssh keys for #{user_name}." do
    user user_name
    creates "#{ssh_dir}/id_rsa.pub"
    command "ssh-keygen -t rsa -q -f #{ssh_dir}/id_rsa -P \"\""
  end
end
