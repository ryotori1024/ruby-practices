require 'optparse'
require 'etc'

# メインメソッド
def main
  opt = OptionParser.new
  params = {}

  opt.on('-a') { |v| params[:a] = v }
  opt.on('-l') { |v| params[:l] = v }
  opt.on('-r') { |v| params[:r] = v }

  opt.parse!(ARGV)
  # カレントディレクトリ内のファイルを取得して配列に格納する
  files_name = Dir.foreach('.').to_a
  # aオプションが付けられていない場合は、先頭にピリオドがあるファイルを配列から除外する
  files_name = files_name.filter { |file_name| !file_name.start_with?('.') } unless params[:a]
  # 取得したファイル名を昇順にソート
  files_name = files_name.sort.to_a

  # rオプションが付与されている場合は、配列を逆順にソートする
  files_name = files_name.reverse.to_a if params[:r]

  if params[:l]
    # lオプションが付与されている場合は、ファイルの各情報を出力する処理を行う
    l_option(files_name)
  else
    # lオプションが付与されていない場合は、ファイル名のみを表示する処理を行う
    none_l_option(files_name)
  end
end

# lオプションの処理を行うメソッド
def l_option(file_names)
  # ファイル名を格納した配列の各要素のFile::Statインスタンスを作成し、新しい配列に格納
  files = file_names.map do |file|
    File::Stat.new(file)
  end

  # クラス配列内の各インスタンスのファイルモードを8進数に変換し、配列に格納
  files_mode_tos8 = filesmode_tos8conversion(files)

  # 取得したファイルモード(8進数)から権限を取得する
  owner_authority = []            # 所有者権限
  owner_group_authority = []      # 所有グループ権限
  other_authority = []            # その他権限
  i = 0
  files_mode_tos8.each do |files_mode|
    owner_authority[i] = files_mode[3, 1]
    owner_group_authority[i] = files_mode[4, 1]
    other_authority[i] = files_mode[5, 1]
    i += 1
  end

  owner_authority = make_authority(owner_authority)
  owner_group_authority = make_authority(owner_group_authority)
  other_authority = make_authority(other_authority)
  # ファイルモードの8進数上位2桁の値によって、ファイルの種類を判定
  file_type = file_type_judge(files)

  j = 0
  # ファイルモードを連結してパーミッションを作成し配列に格納
  files_permission = []
  file_names.length.times do
    files_permission[j] = file_type[j] + owner_authority[j] + owner_group_authority[j] + other_authority[j]
    j += 1
  end

  # ファイルのハードリンク数、 ユーザー名、グループ名、ファイルサイズ、タイムスタンプを取得し配列に格納
  files_hardlink = files.map(&:nlink)
  files_username = files.map do |file|
    Etc.getpwuid(file.uid).name
  end
  files_groupname = files.map do |file|
    Etc.getgrgid(file.gid).name
  end
  files_size = files.map(&:size)
  files_time = files.map(&:mtime)

  # ファイルのブロック数の合計を求める
  file_block = files.sum(&:blocks)

  # ファイルの各情報を出力
  l_option_output(file_names, file_block, files_permission,
                  files_hardlink, files_username, files_groupname, files_size, files_time)
end

# ファイルモードを8進数に変換するメソッド
def filesmode_tos8conversion(files)
  files.map do |file|
    if file.mode.to_s(8).length == 5
      # ファイルモードが5桁の場合は、先頭に0を付ける
      [0.to_s, file.mode.to_s(8)].join
    else
      file.mode.to_s(8)
    end
  end
end

# 取得したファイルモードからファイルの種類を判定するメソッド
def file_type_judge(files)
  file_type_hush = { '04' => 'd', '10' => '-', '12' => 'l' }
  files.map do |file|
    # ファイルモードの上位2桁を取得
    top_2digit =
      if file.mode.to_s(8).length == 5
        # ファイルモードが5桁の場合は、先頭に0を付けてから取得
        [0.to_s, file.mode.to_s(8)].join[0, 2]
      else
        file.mode.to_s(8)[0, 2]
      end
    # ハッシュから上位2桁の値に応じたファイルの種類を取得
    file_type_hush[top_2digit]
  end
end

# 権限を表す数値(8進数)を2進数に変換したのち、対応に基づいて権限の記号を付与するメソッド
def make_authority(authority)
  authority_hush = { '0' => '---', '1' => '--x', '10' => '-w-', '11' => '-wx', '100' => 'r--',
                     '101' => 'r-x', '110' => 'rw-', '111' => 'rwx' }
  authority.map do |item|
    authority_hush[(item.to_i).to_s(2)]
  end
end

# lオプションの結果と同じような形式でファイルの情報を出力するメソッド
def l_option_output(file_names, file_block, files_permission,
                    files_hardlink, files_username, files_groupname,
                    files_size, files_time)
  i = 0
  # Timeインスタンスを生成
  nowis = Time.new
  # ブロック数を出力
  puts ['total ', file_block.to_s].join
  file_names.length.times do
    outputs = []
    outputs << files_permission[i] << files_hardlink[i] << files_username[i]
    outputs << files_groupname[i] << files_size[i].to_s << files_time[i].month.to_s
    outputs << files_time[i].day.to_s
    if nowis.year != files_time[i].year
      # タイムスタンプの年と、現在の年が異なっている場合は時間ではなく年を表示
      outputs << files_time[i].year.to_s
    else
      # タイムスタンプの年と、現在の年が同じの場合は時間、分を出力
      # タイムスタンプの時間と分が一桁の場合は、0を付けて出力
      hour =
        if files_time[i].hour.to_s.length == 1
          ['0', files_time[i].hour.to_s, ':'].join
        else
          [files_time[i].hour.to_s, ':'].join
        end
      min =
        if files_time[i].min.to_s.length == 1
          ['0', files_time[i].min.to_s].join
        else
          [files_time[i].min.to_s].join
        end
      outputs << [hour, min].join
    end
    outputs << file_names[i]
    puts outputs.join(' ')
    i += 1
  end
end

# lオプションを付けない場合の処理を行うメソッド
def none_l_option(files)
  # 表示する行数
  column = 3

  # 1列あたりの行数を求める
  row = (files.length.to_f / column).ceil

  # ファイル数が「1列あたりの行数の倍数」でない場合
  # 配列を行列に見立てた場合に、行と列の数がズレてエラーになるので
  # nilを挿入して行と列の数を揃える
  if (files.length % column) != 0
    count = column * row - files.length
    count.times do
      files.push(nil)
    end
  end

  # 1列あたりの行数で配列を分割
  files = files.each_slice(row).to_a

  # 配列を行列と見立てて行と列を入れ替え
  files = files.transpose

  # ファイル名を出力
  none_l_option_output(files, column)
end

# lオプションを付けない場合にファイル名を出力するメソッド
def none_l_option_output(files, _column)
  # nilの要素は配列から除外する
  files = files.map(&:compact)
  files.each do |file|
    output = ''
    file.each do |f|
      output += [f.ljust(15, ' ')].join
    end
    print(output)
    print("\n")
  end
end

main
