import openai
import sys
import json
import os
from typing import List, Dict
from pathlib import Path
from dataclasses import dataclass, field
import traceback
from langchain_community.embeddings import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_community.document_loaders import (
    DirectoryLoader, 
    TextLoader,
    PyPDFLoader,
    UnstructuredPDFLoader,
    UnstructuredWordDocumentLoader,
    UnstructuredFileLoader,
    YoutubeLoader
)
from langchain_community.document_loaders.blob_loaders.youtube_audio import YoutubeAudioLoader
from langchain_community.document_loaders.blob_loaders import FileSystemBlobLoader
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import io

# 设置输出编码为 utf-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

@dataclass
class ErrorInfo:
    error_type: str
    error_message: str
    file_path: str
    line_number: int
    function_name: str
    code_context: str
    stack_trace: str
    suggestion: str = ""
    doc_references: Dict[str, str] = field(default_factory=dict)  # 添加文档引用字段


class KnowledgeBase:
    def __init__(self):
        self.embeddings = OpenAIEmbeddings()
        self.vector_store = None
        self.supported_extensions = {
            '.txt': TextLoader,
            '.pdf': PyPDFLoader,
            '.doc': UnstructuredWordDocumentLoader,
            '.docx': UnstructuredWordDocumentLoader,
            '.mp3': self._load_audio,
            '.wav': self._load_audio,
            '.m4a': self._load_audio,
            '.mp4': self._load_video,
            '.avi': self._load_video,
            '.mov': self._load_video,
            '.url': self._load_youtube
        }
        self.doc_vector_store = None  # 用于存储官方文档


    def load_knowledge(self, knowledge_dir: str = "fmri_knowledge"):
        """加载各种格式的知识文件"""
        try:
            if os.path.exists("faiss_store_fmri"):
                self.vector_store = FAISS.load_local("faiss_store_fmri", self.embeddings)
                return

            all_documents = []
            
            for root, _, files in os.walk(knowledge_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    ext = os.path.splitext(file)[1].lower()
                    
                    try:
                        if ext in self.supported_extensions:
                            loader = self.supported_extensions[ext]
                            if callable(loader):
                                docs = loader(file_path)
                            else:
                                docs = loader(file_path).load()
                            all_documents.extend(docs)
                            print(f"Successfully loaded: {file_path}")
                    except Exception as e:
                        print(f"Error loading {file_path}: {str(e)}")

            text_splitter = CharacterTextSplitter(
                chunk_size=1000,
                chunk_overlap=200
            )
            texts = text_splitter.split_documents(all_documents)
            
            self.vector_store = FAISS.from_documents(texts, self.embeddings)
            self.vector_store.save_local("faiss_store_fmri")
            
        except Exception as e:
            print(f"Knowledge base loading error: {str(e)}")

    def search_knowledge(self, query: str, k: int = 3) -> List[str]:
        """搜索相关知识"""
        if self.vector_store is None:
            return []
        results = self.vector_store.similarity_search(query, k=k)
        return [doc.page_content for doc in results]

    def _load_audio(self, file_path: str):
        """加载音频文件"""
        try:
            import whisper
            model = whisper.load_model("base")
            result = model.transcribe(file_path)
            
            from langchain.schema import Document
            return [Document(
                page_content=result["text"],
                metadata={"source": file_path, "type": "audio"}
            )]
        except Exception as e:
            print(f"Error transcribing audio {file_path}: {str(e)}")
            return []

    def _load_video(self, file_path: str):
        """加载视频文件"""
        try:
            import moviepy.editor as mp
            video = mp.VideoFileClip(file_path)
            audio_path = file_path + ".wav"
            video.audio.write_audiofile(audio_path)
            
            docs = self._load_audio(audio_path)
            
            os.remove(audio_path)
            video.close()
            
            return docs
        except Exception as e:
            print(f"Error processing video {file_path}: {str(e)}")
            return []

    def _load_youtube(self, file_path: str):
        """加载YouTube视频"""
        try:
            with open(file_path, 'r') as f:
                youtube_url = f.read().strip()
            
            loader = YoutubeLoader.from_youtube_url(
                youtube_url,
                add_video_info=True
            )
            return loader.load()
        except Exception as e:
            print(f"Error loading YouTube content {file_path}: {str(e)}")
            return []


class DocFetcher:
    """文档获取器"""
    def __init__(self):
        self.matlab_base_url = "https://www.mathworks.com/help"
        self.python_base_url = "https://docs.python.org/3"
        self.session = requests.Session()
        
    def get_error_docs(self, error_info: ErrorInfo) -> Dict[str, str]:
        """获取错误相关的官方文档"""
        docs = {
            'matlab': self._get_matlab_docs(error_info),
            'python': self._get_python_docs(error_info)
        }
        return docs

    def _get_matlab_docs(self, error_info: ErrorInfo) -> str:
        """获取MATLAB相关文档"""
        try:
            search_url = f"{self.matlab_base_url}/search.html?qdoc={error_info.error_type}"
            response = self.session.get(search_url)
            soup = BeautifulSoup(response.text, 'html.parser')
            relevant_content = []
            for result in soup.select('.search_result')[:3]:
                title = result.select_one('.result_title')
                desc = result.select_one('.result_text')
                if title and desc:
                    doc_url = urljoin(self.matlab_base_url, title.get('href', ''))
                    doc_response = self.session.get(doc_url)
                    doc_soup = BeautifulSoup(doc_response.text, 'html.parser')
                    content = doc_soup.select_one('.doc_content_container')
                    if content:
                        relevant_content.append(r"""
来源: MATLAB文档 - {title.text.strip()}
链接: {doc_url}
内容:
{content.text.strip()[:500]}...  # 截取前500字符
""")
            return "\n---\n".join(relevant_content)
        except Exception as e:
            print(f"Error fetching MATLAB docs: {str(e)}")
            return ""
            
    def _get_python_docs(self, error_info: ErrorInfo) -> str:
        """获取Python相关文档"""
        try:
            search_url = f"{self.python_base_url}/search.html?q={error_info.error_type}&check_keywords=yes&area=default"
            response = self.session.get(search_url)
            soup = BeautifulSoup(response.text, 'html.parser')
            relevant_content = []
            for result in soup.select('.search-result-item')[:3]:
                link = result.select_one('a')
                if link:
                    doc_url = urljoin(self.python_base_url, link.get('href', ''))
                    doc_response = self.session.get(doc_url)
                    doc_soup = BeautifulSoup(doc_response.text, 'html.parser')
                    content = doc_soup.select_one('.section')
                    if content:
                        relevant_content.append(r"""
参考: Python文档 - {link.text.strip()}
链接: {doc_url}
内容:
{content.text.strip()[:500]}...  # 截取前500字符
""")
            return "\n---\n".join(relevant_content)
        except Exception as e:
            print(f"Error fetching Python docs: {str(e)}")
            return ""
class ErrorAnalyzer:
    def __init__(self, toolbox_path: str):
        self.toolbox_path = Path(toolbox_path)
        self.code_cache = {}
        self.error_patterns = self._initialize_error_patterns()
        self._load_toolbox_code()
        self.doc_fetcher = DocFetcher()

    def _initialize_error_patterns(self) -> Dict:
        """初始化错误模式库"""
        return {
            'TypeError': {
                'pattern': r'(\w+)\(\) takes (\d+) positional argument but (\d+) were given',
                'suggestion': "函数参数数量不匹配。请检查函数定义和调用处的参数数量是否一致。"
            },
            'ValueError': {
                'pattern': r'could not convert string to float: (.*)',
                'suggestion': "输入格式错误。请确保输入的数据类型正确。"
            },
            'IndexError': {
                'pattern': r'list index out of range',
                'suggestion': "数组索引越界。请检查数组长度和索引值。"
            },
            'FileNotFoundError': {
                'pattern': r'No such file or directory: (.*)',
                'suggestion': "文件不存在。请检查文件路径是否正确。"
            },
            'AttributeError': {
                'pattern': r"'(.+)' object has no attribute '(.+)'",
                'suggestion': "对象属性不存在。请检查对象类型和属性名称。"
            },
            # MATLAB特定错误
            'MatlabError': {
                'pattern': r'Undefined function or variable [\'"](\w+)[\'"]',
                'suggestion': "未定义的函数或变量。请检查变量名是否正确，函数是否在路径中。"
            }
        }

    def _load_toolbox_code(self):
        """加载toolbox代码到缓存"""
        for file_path in self.toolbox_path.rglob('*'):
            if file_path.suffix in ['.m', '.py']:
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        self.code_cache[str(file_path)] = f.read()
                except Exception as e:
                    print(f"Error loading {file_path}: {e}")

    def analyze_error(self, error: Exception) -> ErrorInfo:
        """分析错误并返回详细信息"""
        tb = traceback.extract_tb(error.__traceback__)
        error_frame = tb[-1]

        error_info = ErrorInfo(
            error_type=type(error).__name__,
            error_message=str(error),
            file_path=error_frame.filename,
            line_number=error_frame.lineno,
            function_name=error_frame.name,
            code_context=self._get_code_context(error_frame.filename, error_frame.lineno),
            stack_trace=''.join(traceback.format_tb(error.__traceback__))
        )
        # 获取官方文档参考
        try:
            matlab_doc = self._get_matlab_doc_reference(error_info)
            python_doc = self._get_python_doc_reference(error_info)
            error_info.doc_references = {
                'matlab': matlab_doc,
                'python': python_doc
            }
        except Exception as e:
            print(f"Warning: Could not fetch documentation: {str(e)}")

        # 生成错误分析和建议
        error_info.suggestion = self._generate_analysis(error_info)
        
        return error_info

    def _get_matlab_doc_reference(self, error_info: ErrorInfo) -> str:
        """从MATLAB官方文档获取相关参考"""
        try:
            url = f"https://www.mathworks.com/help/search.html?qdoc={error_info.error_type}"
            response = requests.get(url)
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                relevant_content = []
                for result in soup.select('.search_result')[:2]:  # 获取前2个结果
                    title = result.select_one('.result_title')
                    desc = result.select_one('.result_text')
                    if title and desc:
                        relevant_content.append(r"""
参考: {title.text.strip()}
描述: {desc.text.strip()}
链接: {urljoin('https://www.mathworks.com', title.get('href', ''))}
""")
                return "\n".join(relevant_content)
        except Exception as e:
            print(f"Warning: Failed to fetch MATLAB documentation: {str(e)}")
        return ""

    def _get_python_doc_reference(self, error_info: ErrorInfo) -> str:
        """从Python官方文档获取相关参考"""
        try:
            url = f"https://docs.python.org/3/search.html?q={error_info.error_type}&check_keywords=yes&area=default"
            response = requests.get(url)
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                relevant_content = []
                for result in soup.select('.search-result-item')[:2]:  # 获取前2个搜索结果
                    link = result.select_one('a')
                    desc = result.select_one('div.context')
                    if link and desc:
                        relevant_content.append(r"""
参考: {link.text.strip()}
描述: {desc.text.strip()}
链接: {urljoin('https://docs.python.org/3/', link.get('href', ''))}
""")
                return "\n".join(relevant_content)
        except Exception as e:
            print(f"Warning: Failed to fetch Python documentation: {str(e)}")
        return ""
    
    def _generate_analysis(self, error_info: ErrorInfo) -> str:
        """生成综合错误分析"""
        analysis = r"""
错误分析报告:
-------------
错误类型: {error_info.error_type}
错误信息: {error_info.error_message}
文件位置: {error_info.file_path}
行号: {error_info.line_number}
函数名: {error_info.function_name}

代码上下文:
{error_info.code_context}

相关文档参考:
-------------
MATLAB文档:
{error_info.doc_references.get('matlab', '未找到相关MATLAB文档')}

Python文档:
{error_info.doc_references.get('python', '未找到相关Python文档')}

错误分析:
{self._analyze_error_type(error_info)}
"""
        return analysis

    def _generate_solution(self, error_info: ErrorInfo, docs: Dict[str, str]) -> str:
        """基于错误信息和文档生成解决方案"""
        prompt = r"""
基于以下信息生成解决方案：

错误类型: {error_info.error_type}
错误信息: {error_info.error_message}
代码上下文:
{error_info.code_context}

相关文档参考:
{docs['matlab']}
{docs['python']}

请提供具体的解决步骤和示例代码。
"""
        try:
            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"无法生成解决方案: {str(e)}"
        
    def _get_code_context(self, file_path: str, line_number: int, context_lines: int = 3) -> str:
        """获取错误发生位置的代码上下文"""
        try:
            if file_path in self.code_cache:
                code = self.code_cache[file_path]
                lines = code.split('\n')
                start = max(0, line_number - context_lines - 1)
                end = min(len(lines), line_number + context_lines)
                
                context = []
                for i in range(start, end):
                    line_marker = '-> ' if i == line_number - 1 else '   '
                    context.append(f"{line_marker}{i+1}: {lines[i]}")
                
                return '\n'.join(context)
        except Exception as e:
            return f"Could not get code context: {e}"
        
        return "Code context not available"

    def _analyze_error_type(self, error_info: ErrorInfo) -> str:
        """根据错误类型提供具体建议"""
        if error_info.error_type in self.error_patterns:
            pattern = self.error_patterns[error_info.error_type]['pattern']
            match = re.search(pattern, error_info.error_message)
            if match:
                return self.error_patterns[error_info.error_type]['suggestion']

        return self._get_ai_suggestion(error_info)

    def _get_ai_suggestion(self, error_info: ErrorInfo) -> str:
        """使用OpenAI API获取错误分析建议"""
        try:
            prompt = r"""
            分析以下代码错误并提供解决方案：

            错误类型: {error_info.error_type}
            错误信息: {error_info.error_message}
            文件: {error_info.file_path}
            行号: {error_info.line_number}
            函数: {error_info.function_name}

            代码上下文:
            {error_info.code_context}

            堆栈跟踪:
            {error_info.stack_trace}

            请提供：
            1. 错误原因分析
            2. 可能的解决方案
            3. 代码示例（如果适用）
            """

            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7
            )

            return response.choices[0].message.content

        except Exception as e:
            return f"AI分析失败: {str(e)}"

class FMRIAssistant:
    def __init__(self, toolbox_path: str):
        self.openai_api_key = 'sk-Y296nq3B9UsfGQlT74087eA7F4Cc4a25Bd432737Af448e23'
        self.base_url = "https://free.v36.cm/v1/"
        self.knowledge_base = KnowledgeBase()
        self.doc_fetcher = DocFetcher()  # 文档获取器
        self.error_analyzer = ErrorAnalyzer(toolbox_path)  # 错误分析器，修复错误的类实例
        self.chat_history = []
        self.initialize_openai()

    def initialize_openai(self):
        openai.api_key = self.openai_api_key
        openai.base_url = self.base_url

    def process_query(self, query: str, error_message: str = None) -> str:
        try:
            if error_message:
                return self.handle_error(error_message)
            else:
                relevant_docs = self.knowledge_base.search_knowledge(query)
                return self._get_ai_response(query, relevant_docs)
        except Exception as e:
            return f"处理查询时出错: {str(e)}"

    def handle_error(self, error: Exception) -> str:
        try:
            error_info = self.error_analyzer.analyze_error(error)  # 使用 ErrorAnalyzer 类的 analyze_error 方法
            return error_info.suggestion
        except Exception as e:
            return f"错误分析失败: {str(e)}"

    def _get_ai_response(self, query: str, relevant_docs: List[str]) -> str:
        try:
            prompt = r"""
            基于以下参考资料回答问题：

            问题：
            {query}

            参考资料：
            {'\n'.join(relevant_docs)}

            请提供详细的答案，如果涉及代码，请给出示例。
            """

            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7
            )

            return response.choices[0].message.content
        except Exception as e:
            return f"AI响应失败: {str(e)}"

def main():
    if len(sys.argv) < 2:
        print("Usage: python chatgpt_api.py \"your question here\" [\"error message\"]")
        sys.exit(1)

    toolbox_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assistant = FMRIAssistant(toolbox_path)
    
    query = sys.argv[1]
    error_message = sys.argv[2] if len(sys.argv) > 2 else None
    
    response = assistant.process_query(query, error_message)
    print(response)

if __name__ == "__main__":
    main()