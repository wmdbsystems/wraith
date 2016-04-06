require "_helpers"

describe "Wraith helpers classes and functions" do

  describe "the convert_to_absolute function" do
    it "should return false if no filepath provided" do
      expect(convert_to_absolute(nil)).to eq 'false'
    end

    it "should convert a relative path to absolute" do
      relative = 'my/filepath'
      absolute = convert_to_absolute relative
      expect(absolute[0]).to eq '/'
      expect(absolute.length).to be > relative.length
      expect(absolute).to match(/\/(.+)\/(.+)\/my\/filepath/)
    end

    it "should leave an absolute path unchanged" do
      relative = '/my/filepath'
      absolute = convert_to_absolute relative
      expect(absolute).to eq relative
    end

    it "should leave a Windows-flavoured absolute path unchanged" do
      relative = 'C:/Code/Wraith/javascript/global.js'
      absolute = convert_to_absolute relative
      expect(absolute).to eq relative
    end
  end

end
