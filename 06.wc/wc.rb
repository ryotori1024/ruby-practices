require 'optparse'

opt = OptionParser.new

params = {}
opt.on('-l') { |v| params[:l] = v }
opt.parse!(ARGV)
files_argv = ARGV

word_count = byte_count = 0
line_total = word_total = size_total = 0
if files_argv.empty?
  # コマンドライン引数がない場合、標準入力からの入力を受け付ける
  standard_inputs = []
  while stdin = $stdin.gets
    standard_inputs << stdin.split
  end

  # 標準入力から入力された文字列の単語数、バイト数を数える
  standard_inputs.each do |input|
    word_count += input.length
    byte_count += input.join(' ').size
  end
  byte_count += standard_inputs.length
  puts "       #{standard_inputs.size}       #{word_count}      #{byte_count}"
else

  # ファイルの行数、単語数、バイト数、ファイル名を表示する処理
  i = 0
  files_argv.each do |file_name|
    File.open(file_name) do |f|
      line_count = word_count = size_count = 0
      # ファイルから1行ずつ取り出して処理を行う
      f.each_line do |line|
        p line.size
        size_count += line.size

        # 行末の改行文字を取り除く
        line.chomp!
        line_count += 1

        # splite(/\s+/) で単語に分割した後に
        # reject{|w| w.empty?} で空白の文字列を除去する。
        # (行頭に空白がある場合は
        #  split の結果に空白の文字列が含まれるため)
        words = line.split(/\s+/).reject(&:empty?)
        word_count += words.size
      end
      line_total += line_count
      word_total += word_count
      size_total += size_count
      if params[:l]
        # -lオプションが付与されている場合は、行数とファイル名のみ表示
        puts "       #{line_count} #{files_argv[i]}"
      else
        # オプションなしの場合は行数、単語数、バイト数、ファイル名を表示
        puts "       #{line_count}       #{word_count}      #{size_count} #{files_argv[i]}"
      end
      i += 1
    end
  end

  # コマンドライン引数に渡されたファイル名が2つ以上の場合のみ、合計値を表示
  if files_argv.length >= 2
    if params[:l]
      puts "       #{line_total} total"
    else
      puts "       #{line_total}       #{word_total}      #{size_total} total"
    end
  end
end
