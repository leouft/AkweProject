from getpass import getpass
from pwdlib import PasswordHash

senha = getpass("Digite a senha do administrador: ")

hash_senha = PasswordHash.recommended().hash(senha)

print("\nHash gerado:\n")
print(hash_senha)