import sys

if __name__ == "__main__":
    path_all = sys.argv[1]
    path_delete = sys.argv[2]
    path_out = sys.argv[3]

    with open(path_all, 'r') as file_all, \
            open(path_delete, 'rw') as file_delete, \
            open(path_out, 'w') as file_out:

        text_all = file_all.readlines()
        text_delete = file_delete.readlines()

        text_out = set(text_all) - set(text_delete)
        file_out.writelines(text_out)
