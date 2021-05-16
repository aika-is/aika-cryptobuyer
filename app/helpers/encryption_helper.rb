module EncryptionHelper
	def encrypt_text(inner_key, text)
    	salt = SecureRandom.hex

    	cipher = OpenSSL::Cipher.new('DES-EDE3-CBC').encrypt
		cipher.key = "#{ENV['ENC_KEY']}#{inner_key}"
		s = cipher.update(text) + cipher.final

		encoded = s.unpack('H*')[0].upcase
		return encoded
	end

	def decrypt_text(inner_key, encoded)
		cipher = OpenSSL::Cipher.new('DES-EDE3-CBC').decrypt
		cipher.key = "#{ENV['ENC_KEY']}_#{inner_key}"
		s = [encoded].pack("H*").unpack("C*").pack("c*")

		text = cipher.update(s) + cipher.final
		return text
	end
end